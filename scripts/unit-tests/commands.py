#!/usr/bin/python

# Project : ACE Direct Automated Testing 
# Author  : Connor McCann
# Date    : 15 Feb 2018
# Purpose : command class to be used within Unit Tests

import subprocess as sub
import abc
import time


class BaseCommand(object):
	__metaclass__ = abc.ABCMeta

	@abc.abstractmethod
	def execute(self, sleep_time):
		ps = sub.Popen(self.command_list, stdout=sub.PIPE)
		(output, err) = ps.communicate()
		if sleep_time > 0:
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
		self.command_list = ['/usr/bin/sudo', 'asterisk', '-rx']
		self.command_list.append(cs)

	def execute(self, sleep_time):
		return super(AstCommand, self).execute(sleep_time)

