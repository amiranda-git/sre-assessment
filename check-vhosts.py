#!/usr/bin/python3

# SRE Take Home Assessment

# The script utilizes boto3 functionality to download the vhost file from a S3 bucket for ingest and parse. 
# After, the script leverages the urlLib3 lib for request generation. In addition, the runtime has the capability 
# for manipulating connection pools in order to increase connectivity performance. 
# For each script execution, any HTTP request that returns 5xx error codes are displaced to standard output.

import boto3
import urllib3
import re

url = "http://ec2-44-192-109-3.compute-1.amazonaws.com"
vhost_file = "list.vhosts"
text_match = "ServerName"
host_list = []
idx = 0

http = urllib3.PoolManager()
s3 = boto3.client('s3')

response = s3.get_object(Bucket='scratch-storage', Key='vhosts.conf')
data = response['Body'].read().decode()

for line in data.splitlines():
    buf = line.lstrip()
    if not buf.startswith("#"):
        if text_match in buf:
            host_list.insert(idx, buf)
            idx += 1

if len(host_list) == 0:
    print("\n\"" +text_match+ "\"not found\"")
else:
    linelen = len(host_list) 
    for i in range(linelen):
        vh = host_list[i].split()[1]
        resp = http.request("GET","http://ec2-44-192-109-3.compute-1.amazonaws.com",headers={"Host": vh})
        status = re.search("^4", str(resp.status))
        if status:
            print("ALERT Vhost: " + vh + " Status: " + str(resp.status))
        else:
            print("Vhost: " + vh + " Status: " + str(resp.status))
