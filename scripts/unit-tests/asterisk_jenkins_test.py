#!/usr/bin/python

# Project : ACE Direct Automated Testing 
# Author  : Connor McCann
# Date    : 22 Feb 2018
# Purpose : to provide a unit test for Asterisk

import commands as Commands
import subprocess as sub
import unittest
import abc
import sys
import json
import time
import os


class Utilities:
	@staticmethod
	def find_file(fname):
		for root, dirs, files in os.walk('.'):  
			for fileName in files:
				if fileName == fname:
					return os.path.join(root, fname)
					
class AsteriskTests(unittest.TestCase):
	@classmethod
	def setUpClass(cls):
		try:
			# load some values from JSON configuration 
			cls.configFile = Utilities.find_file('asterisk_test_config.json')
			with open(cls.configFile, 'r') as f:
				cls.configs = json.load(f)
							
		except:
			print('Error occured while setting up the test class ---> Aborting Test')
			sys.exit(-1)

	def test_pjsip_endpoints(self):
		# alert the user of the current test
		print ('\nTesting ---> PJSIP Endpoints Loaded?')
		
		com = Commands.AstCommand('pjsip show endpoints')
		rez = com.execute(0)
		lines = rez.split('\n')
		objFound = lines.pop()
		while objFound is "":
			objFound = lines.pop()
		numEndpoints = int(objFound.split(':')[1].strip())
		self.assertEqual(numEndpoints, self.configs['asterisk']['num_endpoints'])
	
#	def test_db_entries(self):
#		# alert the user of the current test
#		print ('\nTesting ---> Asterisk Database Entries?')
#		
#		com = Commands.AstCommand('database show')
#		rez = com.execute(0)
#		lines = rez.split('\n')
#		objFound = lines.pop()
#		while objFound is "":
#			objFound = lines.pop()
#		numEntries = int(objFound.split(' ')[0].strip())
#		self.assertEqual(numEntries, self.configs['asterisk']['num_db_entries'] )		

	def test_cdr_db(self):
		# alert the user of the current test
		print ('\nTesting ---> Asterisk Connected to CDR DB?')
		
		com = Commands.AstCommand('cdr show status')
		rez = com.execute(0)
		lines = rez.split('\n')
		status = ''
		for line in lines:
			words = line.split(':')
			for i, word in enumerate(words):
				clean = word.strip()
				if clean == 'Logging':
					status = words[i+1].strip()
		self.assertEqual(status, "Enabled")
			
	def test_stun_server(self):
		# alert the user of the current test
		print ('\nTesting ---> Asterisk STUN Server?')
	
		com = Commands.AstCommand('stun show status')
		rez = com.execute(0)
		lines = rez.split('\n')
		stunLine = lines.pop()
		while stunLine is "":
			stunLine = lines.pop()
		stun = stunLine.split(' ')[0].strip()
		self.assertEqual(stun, self.configs["asterisk"]["stun"])		

	def test_queues(self):
		# alert the user of the current test
		print ('\nTesting ---> Asterisk Queue Number Non-Zero?')

		com = Commands.AstCommand('queue show')
		rez = com.execute(0)
		# sometimes the queue show returns 'No such command' so loop to get proper resp
		while rez.split(' ')[0].strip() == 'No':
			rez = com.execute(0)
		lines = rez.split('\n')
		queues = []
		for line in lines:
			position = line.find('Queue')
			if position > 0:
				queue = line.split(' ')[0].strip()
				queues.append(queue)
		self.assertEqual(len(queues), self.configs["asterisk"]["num_queues"])


if __name__ == '__main__':
	sys.exit(unittest.main())

