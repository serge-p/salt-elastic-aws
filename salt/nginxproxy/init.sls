nginx_install:
  pkg.installed:
    - name: nginx
  service:
    - running 
    - name: nginx
    - enable: True
    - require:
        - pkg: nginx
        - file: /etc/nginx.conf

/etc/nginx.conf:
  file.managed:
    - source: salt://nginxproxy/files/nginx.conf
