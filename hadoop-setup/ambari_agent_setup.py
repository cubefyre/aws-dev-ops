# Author - Jitender Aswani
# May 2015
# Organization - SparklineData
# Description - Edit Ambari settings based on input params from the launch scripts

import sys, getopt, ConfigParser
#
#
#
def editAmbariServerAgentFile(ambariServerPrivateDNS):
	config = ConfigParser.ConfigParser()
	config.read('ambari-agent.ini')
	#print config.get('server', 'hostname')
	config.set('server', 'hostname', ambariServerPrivateDNS)
	with open('ambari-agent.ini', 'w') as configfile:
		config.write(configfile)

#
#
#
def main(argv):
	ambariServerPrivateDNS = argv[0]
	editAmbariServerAgentFile(ambariServerPrivateDNS)

if __name__ == "__main__":
	if len(sys.argv) < 2:
		print "Usage: ambari_agent_setup ambariServerPrivateDNS"
	else:
		main(sys.argv[1:])


