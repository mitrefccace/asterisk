#!/usr/bin/python

# Project : ACE Direct Automated Installation 
# Author  : Connor McCann
# Date    : 07 Feb 2018
# Purpose : to provide a unit test for the PAC script which 
#	    is responsible for patching Asterisk source code,
#           installing configuration files, and setting up
#           the Asterisk internal database.

import commands as Commands
import subprocess as sub
import unittest
import abc
import sys
import time
import os


class CornerCases(unittest.TestCase):
		
	@classmethod
	def setUpClass(cls):
		# move into scripts dir
		os.chdir('../')
		# temporarily change the .config.sample file name
		os.rename('./.config.sample', './.config')
	
	def test_ast_service_down(self):
       		# stop asterisk service
		com = Commands.OsCommand('sudo service asterisk stop')
		rez = com.execute(1)
       	
       		# check the output of PAC
		com = Commands.OsCommand('sudo ./update_asterisk.sh --config')
		rez = com.execute(0)
		correct = '\x1b[31mError -- \x1b(B\x1b[mAsterisk service is unreachable ---> Installation canceled\n'
		self.assertEqual(rez, correct)
       	
		# start the asterisk service back up
		com = Commands.OsCommand('sudo service asterisk start')
		rez = com.execute(1)
       
	def test_bad_input(self):
       		# check for unrecognized command line args
		com = Commands.OsCommand('sudo ./update_asterisk.sh --config patch ---no-db')
		rez = com.execute(0)
		correct = "\x1b[31mError -- \x1b(B\x1b[munkown argument: try running './update_asterisk.sh --help' for more information  ---> exiting program\n"
		self.assertEqual(rez, correct)
       
	def test_config_install(self):
       		# check the entire configuration process for successs
		com = Commands.OsCommand('sudo ./update_asterisk.sh --config')
		rez = com.execute(0)
		lines = rez.split('\n')
		status = lines.pop()
		while status is '':
			status = lines.pop()
		correct = '\x1b[32mSuccess -- \x1b(B\x1b[mConfiguration complete'
		self.assertEqual(status, correct)
	
	def test_no_dialin_no_db(self):
		# get the old number 
		com = Commands.AstCommand('database get GLOBAL DIALIN')
		rez = com.execute(0)
		dialin = rez.split(':')[1].strip()

		# check that the db function is triggered
		com = Commands.AstCommand('database del GLOBAL DIALIN')
		rez = com.execute(0)
		correct = 'Database entry removed.\n'
		self.assertEqual(rez, correct) 
	
		# check the behavior of PAC
		com = Commands.OsCommand('sudo ./update_asterisk.sh --config --no-db')
		rez = com.execute(0)
		lines = rez.split('\n')
		status = lines.pop()
		while status is '':
			status = lines.pop()
		correct = '\x1b[31mError -- \x1b(B\x1b[mthe Asterisk database does not contain a dialin number ---> Installation Canceled'
		self.assertEqual(status, correct)
		
		# return the value	
		com = Commands.AstCommand('database put GLOBAL DIALIN {}'.format(dialin))
		rez = com.execute(0)

	@classmethod
	def tearDownClass(cls):
		# change the config file name back
		os.rename('./.config', './.config.sample')
		os.chdir('./unit-tests')

	
if __name__ == '__main__':
	sys.exit(unittest.main())

