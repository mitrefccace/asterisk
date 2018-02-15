#!/usr/bin/python

# Project : ACE Direct Automated Testing 
# Author  : Connor McCann
# Date    : 15 Feb 2018
# Purpose : to provide a unit test for Asterisk

import subprocess as sub
import unittest
import abc
import sys
import time
import os


class AsteriskTests(unittest.TestCase):
	
	@classmethod
	def setUpClass(cls):
		# move into scripts dir
		os.chdir('../')
		# temporarily change the .config.sample file name
		os.rename('./.config.sample', './.config')
	
	def test_ast_service_down(self):
       		# stop asterisk service
		com = OsCommand('sudo service asterisk stop')
		rez = com.execute(1)
       	
       		# check the output of PAC
		com = OsCommand('sudo ./update_asterisk.sh --config')
		rez = com.execute(0)
		correct = '\x1b[31mError -- \x1b(B\x1b[mAsterisk service is unreachable ---> Installation canceled\n'
		self.assertEqual(rez, correct)
       	
		# start the asterisk service back up
		com = OsCommand('sudo service asterisk start')
		rez = com.execute(1)
	
	def test_pjsip_endpoints(self):
		com = AstCommand('pjsip show endpoints')
		rez = com.execute(0)
		lines = rez.split('\n')
		objFound = lines.pop()
		while objFound is "":
			objFound = lines.pop()
		numEndpoints = int(objFound.split(':')[1].strip())
		self.assertGreater(numEndpoints, 0)
		
	@classmethod
	def tearDownClass(cls):
		# change the config file name back
		os.rename('./.config', './.config.sample')
		os.chdir('./unit-tests')

class BaseCommand(object):
	__metaclass__ = abc.ABCMeta

	@abc.abstractmethod
	def execute(self, sleep_time):
		ps = sub.Popen(self.command_list, stdout=sub.PIPE)
		(output, err) = ps.communicate()
		if sleep_time:
			time.sleep(sleep_time)
		if not err:
			return output			

class OsCommand(BaseCommand):
	
	def __init__(self, cs):
		self.command_list = cs.split()

	def execute(self, sleep_time):
		return super(OsCommand, self).execute(sleep_time)

class AstCommand(BaseCommand):
	
	def __init__(self, cs):
		self.command_list = ['sudo', 'asterisk', '-rx']
		self.command_list.append(cs)

	def execute(self, sleep_time):
		return super(AstCommand, self).execute(sleep_time)		


if __name__ == '__main__':
	sys.exit(unittest.main())
