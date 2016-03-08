# Build a Secure Cloud ElasticSearch Instance exercise


deploy_vm.sh
~~~

* script to deploy a new Instance in AWS EC2 cloud, 
* script does not take any args


dependencies: 
~~~

1. Install java on the machine before running the script 
2. create authentication key-pair to access AWS console through API and set 2 following environment variables: 

```sh
 export AWS_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXX
 export AWS_SECRET_KEY=XXXXXXXXXXXXXXXXXXXX
```

~~~


### deploy_vm.sh main logic: 

~~~
* check for java executable and env variables 
* install latest ec2cli tools from amazon 
* create new 'test' keypair, returns new private key for SSH access  
* create new 'es' security group and add rule for only incoming connection on port 22 
* generate init shell script for cloud init bootstrap 
* start a new t2.micro instance in EC2 
~~~



### EC2 cloud init script logic: 

~~~
* bootstrap salt into newly created VM 
* clone this repository from github 
* apply salt highstate in a masterless mode to
* install oracle java 
* install, configure and start elasticsearch service 
* health check elasticsearch 
~~~





drop_vm.sh   
~~~
script to terminate given EC2 instance, 
script takes valid instance ID as an argument

~~~

```sh
 export AWS_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXX
 export AWS_SECRET_KEY=XXXXXXXXXXXXXXXXXXXX
```


