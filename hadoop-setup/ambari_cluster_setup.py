# Author - Jitender Aswani
# May 2015
# Organization - SparklineData
# Description - Setup hadoop cluster using amabri blueprint
# curl -H "X-Requested-By: ambari" -X GET -u admin:admin http://ec2.compute-1.amazonaws.com:8080/api/v1/clusters/SparklineOne?format=blueprint
# blog - https://blog.codecentric.de/en/2014/05/lambda-cluster-provisioning/

import sys, getopt

import urllib, base64, json
from urllib2 import Request, urlopen, URLError, HTTPError

ambariBaseUrl = 'http://ambari_server:8080/api/v1'

requestHeaders = { 'User-Agent' : 'Mozilla/4.0 (compatible; MSIE 5.5; Windows NT)', 
	'Authorization': 'Basic ' + base64.b64encode("admin" + ':' + "admin"),
	'X-Requested-By': 'ambari'
}
#
#
#
def getBluePrints():
	blueprintUri = "blueprints"
	url = "/".join([ambariBaseUrl, blueprintUri])
	response = processGetRequest(url)
	print response
	#print response["items"][0]["Blueprints"]["blueprint_name"]
#
#
#
def registerBluePrint(blueprintName, blueprintFile):
	blueprintUri = "blueprints"
	blueprint = json.loads(open(blueprintFile).read())
	url = "/".join([ambariBaseUrl, blueprintUri, blueprintName])
	return processPostRequest(url, blueprint)
#
#
#
def createCluster(blueprintName, clusterName, hostMappingFile, hosts):
	clusterUri = "clusters"
	clusterTemplate = json.loads(open(hostMappingFile).read())
	# edit bp name and host fqdn
	clusterTemplate["blueprint"] = blueprintName
	# check if we have information about all the hosts in the cluster
	if len(hosts) == len(clusterTemplate["host_groups"]):
		for index in range(len(hosts)):
			clusterTemplate["host_groups"][index]["hosts"][0]["fqdn"] = hosts[index]
	else:
		print "Number of hosts supplied on the command line do not match the number of placeholder in the host mapping file"
	print "Submitting cluster template..."
	print clusterTemplate
	url = "/".join([ambariBaseUrl, clusterUri, clusterName])
	return processPostRequest(url, clusterTemplate)
#
#
#
def exportCluster(clusterName):
	clusterUri = "clusters"
	url = "/".join([ambariBaseUrl, clusterUri, clusterName, "?format=blueprint"])
	response = processGetRequest(url)
#
#
#
def processGetRequest(url):
	try:
		# data = urllib.urlencode(data)
		req = Request(url, None, requestHeaders)
		response = urlopen(req)
		return response.read()	
	except HTTPError as e:
		print e.code
		print e.read()
#
#
#
def processPostRequest(url, data):
	try:
		req = Request(url, json.dumps(data), requestHeaders)
		response = urlopen(req)
		return response.read()
	except HTTPError as e:
		print e.code
		print e.read()

#
#
#
def main(argv):
	ambariServerDNS = argv[0]
	blueprintName = argv[1]
	blueprintFile = argv[2]
	clusterName = argv[3]
	hostMappingFile = argv[4]
	hosts = argv[5:]
	global ambariBaseUrl
	ambariBaseUrl = 'http://' + ambariServerDNS + ':8080/api/v1'
	response = registerBluePrint(blueprintName, blueprintFile)
	response = createCluster(blueprintName, clusterName, hostMappingFile, hosts)
	print response

if __name__ == "__main__":
	if len(sys.argv) < 7:
		print "Usage: ambari_setup ambariServerDNS blueprintName, blueprintFile, clusterName, hostMappingFile, {list of internal names for AWS nodes}"
		print "Example: python ambari_setup.py ec2-54-173-66-235.compute-1.amazonaws.com single_server_bp SingleNodeClusterBlueprint.json SparklineOne ClusterHostMapping.json ip-172-31-55-24.ec2.internal"
	else:
		main(sys.argv[1:])


