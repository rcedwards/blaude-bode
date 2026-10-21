"""Exercise the CLI boundary without credentials, network, or model calls."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


WRAPPER = Path(__file__).with_name('claude-code-consult.sh')


class ConsultTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.fake = self.root / 'claude'
        self.fake.write_text('''#!/usr/bin/env python3
import json, os, sys
if sys.argv[1:] == ['--help']:
    print(os.environ.get('TEST_HELP', '--safe-mode --tools --no-session-persistence'))
elif sys.argv[1:] == ['auth', 'status']:
    print(os.environ.get('TEST_AUTH', '{"loggedIn":true}'))
else:
    print(json.dumps({'args': sys.argv[1:], 'packet': sys.stdin.read()}))
    sys.exit(int(os.environ.get('TEST_EXIT', '0')))
''')
        self.fake.chmod(0o755)
        self.env = dict(os.environ, CLAUDE_BIN=str(self.fake))
        self.env.pop('CLAUDE_MODEL', None)
        self.env.pop('CLAUDE_EFFORT', None)

    def run_wrapper(self, *args, packet='', **env):
        return subprocess.run(['bash', str(WRAPPER), *args], input=packet,
                              capture_output=True, text=True,
                              env=dict(self.env, **env), timeout=10)

    def test_review_has_no_tools_and_packet_is_not_in_argv(self):
        result = self.run_wrapper('raw', packet='private packet marker')
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        args = output['args']
        self.assertEqual(args[args.index('--tools') + 1], '')
        self.assertIn('--safe-mode', args)
        self.assertIn('--no-session-persistence', args)
        self.assertNotIn('private packet marker', ' '.join(args))
        self.assertIn('private packet marker', output['packet'])

    def test_pretty_auth_and_model_arguments(self):
        result = self.run_wrapper('plan', '--model', 'chosen-model', '--effort',
                                  'high', 'Review this plan', TEST_AUTH='{\n "loggedIn": true\n}')
        output = json.loads(result.stdout)
        self.assertIn('chosen-model', output['args'])
        self.assertIn('high', output['args'])
        self.assertIn('implementation plan', output['packet'])

    def test_rejects_false_or_invalid_auth(self):
        for status in ('{"loggedIn":false}', 'not json'):
            with self.subTest(status=status):
                result = self.run_wrapper('raw', 'hello', TEST_AUTH=status)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('authentication could not be verified', result.stderr)

    def test_local_errors_do_not_require_auth(self):
        self.assertEqual(self.run_wrapper('--help', TEST_AUTH='invalid').returncode, 0)
        result = self.run_wrapper('raw', packet='', TEST_AUTH='invalid')
        self.assertIn('Prompt is required', result.stderr)
        result = self.run_wrapper('raw', '--file', '/nonexistent', 'hello', TEST_AUTH='invalid')
        self.assertIn('Unreadable file', result.stderr)

    def test_focused_attachment_and_range_validation(self):
        path = self.root / 'example file.txt'
        path.write_text('one\ntwo\nthree\n')
        result = self.run_wrapper('solution', '--file', f'{path}:2-3', 'review')
        packet = json.loads(result.stdout)['packet']
        self.assertIn('two', packet)
        self.assertIn('three', packet)
        self.assertNotIn('\tone', packet)
        result = self.run_wrapper('raw', '--file', f'{path}:3-2', 'review')
        self.assertIn('Invalid line range', result.stderr)

    def test_rejects_bad_options_and_unsupported_cli(self):
        result = self.run_wrapper('raw', '--bogus', 'hello')
        self.assertIn('Unknown option', result.stderr)
        result = self.run_wrapper('raw', 'hello', TEST_HELP='--tools')
        self.assertIn('update the CLI', result.stderr)
        self.assertNotEqual(result.returncode, 0)

    def test_range_edges_and_directory(self):
        path = self.root / 'lines.txt'
        path.write_text('line\n' * 12)
        self.assertEqual(self.run_wrapper('raw', '--file', f'{path}:08-09', 'review').returncode, 0)
        for extent in ('0-2', '4-2', '1-401'):
            result = self.run_wrapper('raw', '--file', f'{path}:{extent}', 'review')
            self.assertIn('Invalid line range', result.stderr)
        result = self.run_wrapper('raw', '--file', f'{path}:20-21', 'review')
        self.assertIn('Empty line range', result.stderr)
        result = self.run_wrapper('raw', '--file', str(self.root), 'review')
        self.assertIn('Unreadable file', result.stderr)

    def test_oversized_attachment_and_cli_failure(self):
        path = self.root / 'large.txt'
        path.write_text('line\n' * 401)
        result = self.run_wrapper('raw', '--file', str(path), 'review')
        self.assertIn('Refusing to inline', result.stderr)
        self.assertEqual(self.run_wrapper('stuck', 'review', TEST_EXIT='7').returncode, 7)


if __name__ == '__main__':
    unittest.main()
