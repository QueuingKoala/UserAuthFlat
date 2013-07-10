UserAuthFlat Testing Reference README

Best viewed with word wrap enabled

SOURCES AND PURPOSE

testSute.au3 is the primary test vector and is designed to be run after changes to the UAF library. Not every situation or return case is tested, but the majority of important cases are. This suite can be extended to handle additional test cases, or limited to perform a (quicker) subset of the tests.

regenAuths.au3 will generate new \testref\basic.auth and \testref\auths\auth-cases.auth files. These are then used by testSuite.au3 to test compliance. It is of course important to verify correct operation of the library before re-generating the auth files, as incorrect library handling would not be tested by the test suite if it matches the undesirable behavior.

timingTest.au3 generates timings for storing and checking a single user/pass combo for all supported hashes with a defined number of rounds. Since storing and checking both use the same backend crypto code, the timings should be nearly-identical, but both checks are included by default. This can be used to gauge an ideal number of rounds when balancing between hash brute-force security and system responsiveness in a specific environment.

DESCRIPTION OF AUTH FILES

\testref\basic.auth is the 'basic' auth test, used generally to test reading and basic password checking.

\testref\auths\auth-cases.auth is a fuller test of all supported hashes, with both the defined default round-count and a round count of '1' for each case. Additionally, it defines some lines with are either invalid, or will never correspond to any hash (but are correctly-formatted lines.) These 'expected-bad' lines are used to check error handling conditions.