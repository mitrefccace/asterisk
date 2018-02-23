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
		# load some values from JSON configuration 
		cls.configFile = "./asterisk_test_config.json"
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
	
	def test_pjsip_endpoints(self):
		com = Commands.AstCommand('pjsip show endpoints')
		rez = com.execute(0)
		lines = rez.split('\n')
		objFound = lines.pop()
		while objFound is "":
			objFound = lines.pop()
		numEndpoints = int(objFound.split(':')[1].strip())
		self.assertGreater(numEndpoints, 0)
	
	def test_db_entries(self):
		com = Commands.AstCommand('database show')
		rez = com.execute(0)
		lines = rez.split('\n')
		objFound = lines.pop()
		while objFound is "":
			objFound = lines.pop()
		numEntries = int(objFound.split(' ')[0].strip())
		self.assertGreater(numEntries, 0)		

	def test_cdr_db(self):
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
		com = Commands.AstCommand('stun show status')
		rez = com.execute(0)
		lines = rez.split('\n')
		stunLine = lines.pop()
		while stunLine is "":
			stunLine = lines.pop()
		stun = stunLine.split(' ')[0].strip()
		self.assertEqual(stun, self.configs["asterisk"]["stun"])		

	def test_queues(self):
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
		self.assertEqual(len(queues), self.configs["asterisk"]["numQueues"])

	@classmethod
	def tearDownClass(cls):
		# change the config file name back
		os.rename('./.config', './.config.sample')
		os.chdir('./unit-tests')

		
if __name__ == '__main__':
	sys.exit(unittest.main())

