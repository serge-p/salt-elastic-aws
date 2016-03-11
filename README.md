# Secure ElasticSearch Instance Autoprovision in AWS


## Overview: 

Building secure elasticsearh node, a set of nodes or a cluster in AWS EC2 cloud
additionally putting it behnd nginx ssl proxy, listening on port 443   
and creating custom security EC2 group as a firewall

Will use AWS Cloud Plugin for automatic nodes discovery 
and trial version of ES Shield Plugin for:

* role-based authentication for https clients  
* audit for a connected clients
* encrypted communicaton between the nodes in the cluster 
* encrypted communicaton for external https clients 



##  example run: 

```shell
git clone https://github.com/serge-p/salt-elastic-aws 
cd salt-elastic-aws
./deploy_vm.sh 2 
```


## healthcheck:     

navigate to `https://$PUBLICIP/_cat/nodes?v` in your browser and 
login as `esadmin:test123` 


example output: 

```
host          ip            heap.percent ram.percent load node.role master name      
172.31.52.173 172.31.52.173            7          81 0.00 d         m      esnode-02 
```



## connection details:     


save a new ssh key and public IPs  from an output of deploy_vm.sh 
and use them to connect to the new VMs as following: 

```
ssh -i test.pem ec2-user@${PUBLIC_IP}
sudo su - 
``` 


*** 


### deploy_vm.sh

Shell script will deploy a given number of Secured Elasticsearch Instances in AWS EC2 cloud, using ec2 cli tools  

script takes a number of instances as an argument


prereqs: 

1. Install java (and optionally aws cli tools) on test machine before running the script 
2. create authentication key-pair to access AWS console through API and set 2 following environment variables: 


```shell
 export AWS_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXX
 export AWS_SECRET_KEY=XXXXXXXXXXXXXXXXXXXX
```

3. for ec2 auto-discovery, we need to create a new role in IAM from AWS console with name `es-role`  and associate it with following IAM policy:


```json
{
    "Statement": [
        {
            "Action": [
                "ec2:DescribeInstances"
            ],
            "Effect": "Allow",
            "Resource": [
                "*"
            ]
        }
    ],
    "Version": "2012-10-17"
}
```



### deploy_vm.sh main logic: 

~~~~
* check for java env variables 
* install latest ec2cli tools from amazon 
* create new 'test' keypair, returns new private key for SSH access  
* create new 'es' security group and add any custom firewall rules 
* generate init shell script for cloud init bootstrap 
* start a number of t2.micro amazoon linux instance in EC2 
~~~~



### EC2 cloud init script logic: 


* bootstrap [salt]() into newly created VM 
* clone this repo from github 
* apply salt highstate in a [masterless mode](https://docs.saltstack.com/en/latest/topics/tutorials/quickstart.html)


### salt logic (basic part): 

* install base OS packages 
* install oracle java and jce 
* install elasticsearch from custom RPM repo 
* perform a basic healthcheck 


### salt logic (security part): 


* install elasticsearch plugins    
* [enable authentication](https://www.elastic.co/guide/en/shield/current/enable-basic-auth.html) create admin user, enable audit and messaging authentication)  
* [enable SSL/TLS](https://www.elastic.co/guide/en/shield/current/ssl-tls.html) create CA generate and sign certificates on every node
* configure nginx as a proxy for external search requests   



## additional manual steps for a secure cluster configuration: 


Once initial deployment and bootstraping will be completed and each node will be available by it's own IP,
following steps will need to be done manually: 


* copy (scp) CA certificates located `/etc/elasticsearch/shield/ca/certs/cacert.pem` from all nodes to the first node 
* using keytool insert them into truststore on a first node as following:


```
cd /etc/elasticsearch/shield/
keytool -importcert -keystore truststore.jks  -file ca/certs/esnode-02-cacert.pem -alias esnode-02-ca -storepass supersecure -noprompt -trustcacerts

```

* copy (scp) file /etc/elasticsearch/shield/truststore.jks from the first node to all nodes in the cluster
* copy (scp) file /etc/elasticsearch/shield/system_key from the first node to all nodes in the cluster 
* restart all the nodes in the cluster


example output: 

```
host          ip            heap.percent ram.percent load node.role master name      
172.31.52.173 172.31.52.173            7          81 0.00 d         m      esnode-02 
172.31.56.146 172.31.56.146           10          83 0.00 d         *      esnode-01 
```



*** 




### drop_vm.sh   

Script will terminate all (or given) EC2 instances in group `es`, script takes instance ID as an optional  argument


*** 


### references:


[Elastic Search Official Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
[Shield Settings](https://www.elastic.co/guide/en/shield/current/ref-shield-settings.html#ref-ssl-tls-setting)


