# Build a Secure Cloud ElasticSearch Instance Exercise


script will build a new elasticsearh cluster in AWS EC2 cloud
putting backend nodes behind nginx ssl proxy  

will be using shield plugin in this example for:

* role-based authentication 
* SSL/TLS encrypted communicaton between the nodes in the cluster 


~~~
To check cluster configuration you navigate in your browser 
to http://$PUBLIC_IP/_cat/nodes?v
and login with esadmin:test123 
~~~



### deploy_vm.sh

Shell script to deploy a new Instance in AWS EC2 cloud, using ec2 cli tools  

prereqs: 

1. Install java (and optionally aws cli tools) on test machine before running the script 
2. create authentication key-pair to access AWS console through API and set 2 following environment variables: 


```shell
 export AWS_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXX
 export AWS_SECRET_KEY=XXXXXXXXXXXXXXXXXXXX
```



### deploy_vm.sh main logic: 

~~~~
* check for java executable and env variables 
* install latest ec2cli tools from amazon 
* create new 'test' keypair, returns new private key for SSH access  
* create new 'es' security group and add any custom firewall rules 
* generate init shell script for cloud init bootstrap 
* start a new t2.micro instance in EC2 
~~~~



### EC2 cloud init script logic: 

~~~
* bootstrap salt into newly created VM 
* clone this repo from github 
* apply salt highstate in a masterless mode
~~~


### salt logic (basic part): 

~~~
* install base OS packages 
* install oracle java and jce 
* install elasticsearch from custom RPM repo 
* perform a basic healthcheck 
~~~


### salt logic (security part): 

~~~
* install plugins (shield)   
* enable authentication (create admin user, enable shield audit for messaging)  
* enable SSL/TLS (create CA, generate and sign certificates)
* configure nginx as a proxy for search requests   
~~~



### clustering part 

~~~
* provision one more node into the cluster
* advanced healthcheck 
~~~




```
host      ip        heap.percent ram.percent load node.role master name                          
127.0.0.1 127.0.0.1            5          53 0.00 d         *      ip-172-31-12-104.ec2.internal 
```



*** 



### drop_vm.sh   

* terminate given EC2 instance, 
* script takes valid instance ID as an argument



#### references:


[ES shield settings](https://www.elastic.co/guide/en/shield/current/ref-shield-settings.html#ref-ssl-tls-settings

