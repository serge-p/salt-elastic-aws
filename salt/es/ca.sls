/etc/elasticsearch/shield/ca/private:
  file.directory:
    - user: elasticsearch
    - mode: 700 
    - makedirs: True

/etc/elasticsearch/shield/ca/certs:
  file.directory:
    - user: elasticsearch
    - mode: 700 


/etc/elasticsearch/shield/ca/caconfig.cnf:
  file.managed:
    - user: root
    - mode: 440 
    - backup: 
    - source: 'salt://es/files/caconfig.cnf'
    - template: jinja


echo '01' > serial && touch index.txt:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield/ca
    - creates: /etc/elasticsearch/shield/ca/index.txt


openssl req -days 3650 -batch -nodes -config caconfig.cnf -new -x509 -extensions v3_ca -keyout private/cakey.pem -out certs/cacert.pem: 
  cmd.run:
    - cwd: /etc/elasticsearch/shield/ca
    - creates: /etc/elasticsearch/shield/ca/certs/cacert.pem


openssl req -days 3650 -batch -nodes -new -keyout private/server.key -out private/server.csr:
  cmd.run:
    - cwd: /etc/elasticsearch/shield/ca
    - creates: /etc/elasticsearch/shield/ca/private/server.csr

openssl x509 -req -days 3650 -in private/server.csr -out server.crt -CA certs/cacert.pem -CAkey private/cakey.pem  -CAcreateserial:
  cmd.run:
    - cwd: /etc/elasticsearch/shield/ca
    - creates: /etc/elasticsearch/shield/ca/server.crt

