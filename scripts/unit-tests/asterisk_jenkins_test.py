#!/usr/bin/python

# Project : ACE Direct Automated Testing 
# Author  : Connor McCann
# Date    : 12 Apr 2018
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
                        # Wait these many seconds. Needed because docker-entrypoint.sh takes some time
                        seconds_wait = 15
			with open(cls.configFile, 'r') as f:
				cls.configs = json.load(f)
			print('\nWaiting {} seconds before running unit tests..........'.format(seconds_wait))
                        time.sleep(seconds_wait) # trying to see if this helps pass jenkins pipeline
							
		except:
			print('Error occured while setting up the test class ---> Aborting Test')
			sys.exit(-1)

	def test_ast_service_down(self):
		# alert the user of the current test
		print('\nTesting ---> Asterisk Service Up?')
		
		com = Commands.OsCommand('service asterisk status')
		rez = com.execute(0)
		index = rez.find('running') + 1 # returns -1 if substr not found
		self.assertTrue(index)
	
	def test_ast_version(self):
		# alert the user of the current test
		print('\nTesting ---> Asterisk Version Up-To-Date?')
		
		com = Commands.AstCommand('core show version')
		rez = com.execute(0)
		lines = rez.split('\n')
		line = lines.pop()
		while line is "":
			line = lines.pop()
		elems = line.split(' ')
		version = ""
		if elems[0] == 'Asterisk':
			version = elems[1]
		self.assertEqual(version, self.configs['asterisk']['version'])	

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
			
#	def test_odbc_connections(self):
#		# alert the user of the current test
#		print('\nTesting ---> Asterisk ODBC Connected?')
#		
#		com = Commands.AstCommand('odbc show all')
#		rez = com.execute(0)
#		lines = rez.split('\n')
#		bottomLine = lines.pop()
#		while bottomLine is "":
#			bottomLine = lines.pop()
#		content = bottomLine.split(' ')	
#		numConnections = 0
#		for ii, elem in enumerate(content):
#			if elem == 'connections:':
#				numConnections = int(content[ii+1])
#				break
#		self.assertTrue(numConnections)	

	def test_loaded_codecs(self):
		# alert the user of the current test
		print ('\nTesting ---> Asterisk Loaded Codecs?')
	
		com = Commands.AstCommand('core show codecs')
		rez = com.execute(0)
		status = True
		for codec in self.configs['asterisk']['codecs']:
			index = rez.find(codec["name"]) + 1 # returns -1 if not found 
			if not index:
				print('{} was not loaded'.format(codec['name']))
			status = status and index
		self.assertTrue(status)
		
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
		self.assertEqual(stun, self.configs['asterisk']['stun'])		

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
		self.assertEqual(len(queues), self.configs['asterisk']['num_queues'])

	def test_loaded_modules(self):
		# alert the user of the current test
		print ('\nTesting ---> Asterisk Modules Loaded?')

		com = Commands.AstCommand('module show')
		rez = com.execute(0)
		status = True
		for module in self.configs['asterisk']['modules']:
			index = rez.find(module['name']) + 1 # returns -1 if not found 
			if not index:
				print('{} was not loaded'.format(module['name']))
			status = status and index
		self.assertTrue(status)


if __name__ == '__main__':
	sys.exit(unittest.main())

