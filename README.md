# SRE Assessment

The following two scripts are different implementations for the same functionality. The intent of which is to initially ingest a virtual host file. parse it then extract all the host entries in order to compose the proper Host header values at runtime in order to check all the virtual host targets being served from an EC2 instance. The EC2 instance is running 1000 virtual hosts so the fetch times need to be fast.

**check-vhosts.sh** is a Bash script which utilizes cURL to monitor multiple vhosts on a single httpd hosted instance.  

## Runtime Characteristics

After providing the Bash script with a vhost file for ingest and parse. The script then utilizes cURL for request generation, which is done over a polling interval set (seconds) such that it allows enough time to fetch virtual hosts per poll period. In addition, the runtime leverages xargs capability to run multiple asynchronous processes as a means to speed up execution for URL fetch times. During each poll period an event log is written for any HTTP requests that return 5xx error codes.

### Proposed monitoring Integration

For a Bash runtime use case, this script is best hosted on a EC2 instance where an AWSLogs agent can be configured for ingest where the metrics made available on CloudWatch.

####

**check-vhosts.py** is a Python3 script which utilizes urlLib3 monitor multiple vhosts on a single httpd hosted instance. 

## Runtime Characteristics

The script utilizes boto3 function to download the vhost file from a S3 bucket for ingest and parse. After, the script leverages the urlLib3 lib for request generation. In addition, the runtime has the capability for manipulating connection pools in order to increase connectivity performance. For each script execution, any HTTP request that returns 5xx error codes are displaced to standard output.

### Proposed monitoring Integration

For a Python3 runtime use case, this script is best hosts as a AWS Lambda Function where any alert generated can be configured through boto3 to send telemetry to CloudWatch log group

## Proposed Automated Pipline

* For server instances use, deploy through the Golden AMI method (Immutable).
* For serverless use, deploy through Terraform Lambda resource.
