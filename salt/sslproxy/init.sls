nginx_install:
  pkg.installed:
    - name: nginx
  service.running: 
    - name: nginx
    - enable: True
    - require:
        - pkg: nginx
    - watch: 
        - file: /etc/nginx/nginx.conf
        - file: /etc/nginx/conf.d/ssl.conf

/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://nginxproxy/files/nginx.conf

/etc/nginx/conf.d/ssl.conf:
  file.managed:
    - source: salt://nginxproxy/files/ssl.conf
