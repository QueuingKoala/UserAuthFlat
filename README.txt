UserAuthFlat README

Best viewed with word wrap enabled

OVERVIEW

The UserAuthFlat (UAF) library is designed to create an extensible framework for performing user/password authentication using a stored flat file. Its focus is on native usage with the Windows CryptoAPI and simple usage from frontend library callers.

LICENSING

This library and included code is licensed under the GNU AGPL.

See \Licensing\agpl-3.0.txt for full licensing details.

**NOTE** that this license requires that you provide the source (or a link to the source) to any USERS of a system where this code is running. For example, if you authenticate remote access users using this system, you must notify and make available the source to the users connecting into that system; this includes any modifications you make to this code.

INCLUDED PROGRAM TOOLS

Some basic tools are included in the distribution, and for binary packages come pre-compiled and ready to use. These include a frontend GUI Manager and a headless (no graphics) 'Verify By File' user authentication program.

GUI Manager is a graphical frontend to the library allowing the creation, modification, saving, and loading of UAF Auth files. Its use should be intuitive and straight-forward.

UAF_VerifyByFile is a basic program to perform authentication of a user with an existing UAF Auth file and a flat text file of the user to authenticate; both files are passed as parameters to the program. This second file is a plaintext, newline (LF or CRLF) separated file with the username on the first line and password on the 2nd. Successful validation exits with code 0, while errors return 1 or higher.

CODING QUICK START: provided library API examples

Check out the intentionally terse samples in the \examples\ project subdirectory. These samples don't do much error checking, and will therefore be simple and easy to read if you're getting started with the library. Each script in the 'examples' folder demonstrates a specific library usage.

All examples will read in the 'example.auth' UAF auth file if present, and write its state back before exit. This should make it easy to run the examples to learn how to manipulate and call the library for basic tasks. Errors here are silent and not reported (permission or disk errors are the usual cause of load/save calls failing.)

TEST CASES

Tools to test API conformance can be found in the \testref\ project subdirectory. The 'testSuite.au3' file performs the testing, with 'regenAuths.au3' re-generating the auth files used for testcases (such as when the hashing method changes and the computed salts/hashes in the auth files need to be re-generated.)

See \testref\README.txt' for more details.

API DOCUMENTATION

Each library function designed for external use in 'UserAuthFlat.au3' has a commented header in front explaining its purpose, usage, arguments, return, and error values.

The internal functions are documented (albeit less verbosely) and internal API references (such as shared array columns/keys) can be found in 'API_docs\Internal API Reference.txt.'

The storage format for the flat Auth file can be found in 'API_docs\Auth Format.txt.'