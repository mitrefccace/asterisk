import commands as Commands
import subprocess as sub
import unittest
import abc
import sys
import json
import time
import os


def main():
	com = Commands.OsCommand('echo hello')
	rez = com.execute(0)

if __name__ == '__main__':
	sys.exit(main())
# EOF
