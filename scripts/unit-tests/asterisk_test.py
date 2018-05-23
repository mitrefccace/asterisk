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


class AsteriskTests(unittest.TestCase):
		
	@classmethod
	def setUpClass(cls):
		try:
			# load some values from JSON configuration 
			cls.configFile = './asterisk_test_config.json'
			with open(cls.configFile, 'r') as f:
				cls.configs = json.load(f)
			
			# move into scripts dir
			os.chdir('../')
			
			# temporarily change the .config.sample file name
			configFound = False
			for root, dirs, files in os.walk('.'):  
				for fileName in files:
					if fileName == '.config.sample':
						os.rename('.config.sample', '.config')
						configFound = True
						break	
					elif fileName == '.config':
						configFound = True
						break
			if not configFound:
				print('Could not find the .config file in the parent directory ---> Aborting Test')
				sys.exit(-1)
		except:
			print('Error occured while setting up the test class ---> Aborting Test')
			sys.exit(-1)

	def test_ast_service_status(self):
		# alert the user of the current test
		print('\nTesting ---> Asterisk Service Up?')
		com = Commands.OsCommand('service asterisk status')
		rez = com.execute(0)
		lines = rez.split('\n')
		status = ''
		for line in lines:
			words = line.split(':')
			key = words[0].strip()
			if key == 'Active':
				status = words[1].split(' ')[1]	
		self.assertEqual(status, 'active')

	def test_update_ast_output(self):
       		# alert the user of the current test
		print ('\nTesting ---> Update Asterisk Output?')

		# stop asterisk service
		com = Commands.OsCommand('sudo service asterisk stop')
		rez = com.execute(3)
       	
       		# check the output of PAC
		com = Commands.OsCommand('sudo ./update_asterisk.sh --config --backup')
		rez = com.execute(0)
		lines = rez.split('\n')
		msg = lines.pop()
		while msg is "":
			msg = lines.pop()
		correct = '\x1b[31mError -- \x1b(B\x1b[mAsterisk service is unreachable ---> Installation canceled'
		self.assertEqual(msg, correct)
       	
		# start the asterisk service back up
		com = Commands.OsCommand('sudo service asterisk start')
		rez = com.execute(3)
	
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
	
	def test_db_entries(self):
		# alert the user of the current test
		print ('\nTesting ---> Asterisk Database Entries?')
		
		com = Commands.AstCommand('database show')
		rez = com.execute(0)
		lines = rez.split('\n')
		objFound = lines.pop()
		while objFound is "":
			objFound = lines.pop()
		numEntries = int(objFound.split(' ')[0].strip())
		self.assertEqual(numEntries, self.configs['asterisk']['num_db_entries'] )		

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

	@classmethod
	def tearDownClass(cls):
		try:
			# change the config file name back
			os.rename('./.config', './.config.sample')
			os.chdir('./unit-tests')
		except:
			print('Error occured during class teardown')
			sys.exit(-1)
		

if __name__ == '__main__':
	sys.exit(unittest.main())

