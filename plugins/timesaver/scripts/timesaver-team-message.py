#!/usr/bin/env python3
"""Send from the cloud machine. The helper reads the access code itself from the
connected saves folder, so the code never appears in a command, its input or a
permission box. Usage: timesaver-team-message.py --saves-root <folder>, with the
person's message on standard input."""
import datetime
import json
import os
import re
import stat
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

PROMPT = 'What would you like to ask, tell or send Team Mindy?'
SENT = 'Your message has been sent to Team MINDY.'
DUPLICATE = 'Your message was already sent to Team MINDY.'
UNREACHABLE = "Your message hasn't reached us yet, because MINDY TimeSaver couldn't get through just now. Check you're online - your words are kept right here."
ALLOW_DOMAIN = "This chat isn't allowed to reach us yet, so your message hasn't been sent. Open Settings, then Capabilities, and add gate.mindy.build under Additional allowed domains."
NO_CODE = "MINDY TimeSaver couldn't read your access code from the connected folder, so your message hasn't been sent. Click the </> button, choose This computer and type /install-mts with your access code there. Then come back to this chat."
NOT_HERE = "MINDY TimeSaver can't send your message from this chat. Click the </> button, choose This computer and type /mindyteam there."


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class NotHere(Exception):
    pass


class NoCode(Exception):
    pass


def endpoint():
    url = os.environ.get('MTS_TEAM_MESSAGE_TEST_URL', 'https://gate.mindy.build/mts/team-messages')
    if 'MTS_TEAM_MESSAGE_TEST_URL' in os.environ:
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != 'http' or parsed.hostname != '127.0.0.1' or not parsed.port or parsed.path != '/mts/team-messages' or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError('invalid test endpoint')
    return url


# Anything shaped like an access code: letters, digits or hyphens, a full stop,
# then 40 or more letters, digits, hyphens or underscores (an issued code has 86).
# It is removed whether or not the saved code could be read.
CODE_SHAPE = re.compile(r'[A-Za-z0-9-]+\.[A-Za-z0-9_-]{40,}')


def without_codes(text, code=''):
    if code:
        text = text.replace(code, '[access code]')
    return CODE_SHAPE.sub('[access code]', text)


def failure(reason, message, code):
    reason = ' '.join(without_codes(reason, code).splitlines())
    print(reason + ' Your message: ' + json.dumps(without_codes(message, code), ensure_ascii=False) + '. Type /mindyteam again to try again.')
    return 1


def connected_code(root):
    """Read the code copy setup put in the connected saves folder. Nothing else reads it."""
    if not root or not os.path.isabs(root) or not os.path.isdir(root):
        raise NotHere()
    try:
        with open(os.path.join(root, 'timesaver.json'), encoding='utf-8') as handle:
            marker = json.load(handle)
    except (OSError, ValueError):
        raise NotHere()
    if not isinstance(marker, dict) or marker.get('format') != 'mts.connected-folder.v1' or marker.get('product') != 'mts':
        raise NotHere()
    try:
        descriptor = os.open(os.path.join(root, '.timesaver', 'timesaver-access-code'), os.O_RDONLY | os.O_NOFOLLOW)
    except OSError:
        raise NoCode()
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_size > 4096:
            raise NoCode()
        code = os.read(descriptor, 4097).decode('ascii', 'strict')
    except (OSError, UnicodeError):
        raise NoCode()
    finally:
        os.close(descriptor)
    if not 1 <= len(code) <= 4096 or any(ord(c) <= 32 or ord(c) >= 127 for c in code):
        raise NoCode()
    return code


def send(message, code):
    body = dict(report='mts-team-message/v1', messageId=str(uuid.uuid4()), app='Claude app',
                message=without_codes(message, code).strip()[:10000], sentAt=datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z'))
    try:
        request = urllib.request.Request(endpoint(), data=json.dumps(body, ensure_ascii=False, separators=(',', ':')).encode('utf-8'),
                                         headers={'Authorization': 'Bearer ' + code, 'Content-Type': 'application/json', 'User-Agent': 'Bun/1.4.2', 'Accept': '*/*'}, method='POST')
        opener = urllib.request.build_opener(NoRedirect())
        try:
            response = opener.open(request, timeout=15)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            status = response.code
            if status == 201:
                print(SENT)
                return 0
            try:
                answer = json.loads(response.read(65536))
            except (ValueError, UnicodeError):
                answer = None
            if status == 200 and isinstance(answer, dict) and answer.get('duplicate') is True:
                print(DUPLICATE)
                return 0
            if status in (403, 429) and isinstance(answer, dict) and isinstance(answer.get('error'), str) and answer['error'].strip():
                return failure(answer['error'].replace('Mindy TimeSaver', 'MINDY TimeSaver'), message, code)
        return failure(UNREACHABLE, message, code)
    except urllib.error.URLError as error:
        if not isinstance(error, urllib.error.HTTPError) and any(text in str(error.reason) for text in ('Tunnel connection failed', '407', '403', 'Forbidden')):
            return failure(ALLOW_DOMAIN, message, code)
        return failure(UNREACHABLE, message, code)
    except Exception:
        return failure(UNREACHABLE, message, code)


def main(arguments, message):
    if message.endswith('\n'):
        message = message[:-1]
    # Anything shaped like an access code leaves the message before it is used anywhere.
    message = without_codes(message)
    if not message.strip():
        print(PROMPT)
        return 1
    if len(arguments) != 2 or arguments[0] != '--saves-root':
        return failure(NOT_HERE, message, '')
    try:
        code = connected_code(arguments[1])
    except NotHere:
        return failure(NOT_HERE, message, '')
    except NoCode:
        return failure(NO_CODE, message, '')
    return send(message, code)


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:], sys.stdin.read()))
    except Exception:
        print(UNREACHABLE)
        sys.exit(1)
