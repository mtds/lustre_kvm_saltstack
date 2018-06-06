lustre_package:
  pkg.installed:
    - pkgs:
      - kmod-lustre-client
      - lustre-client

{% if grains['fqdn'] == 'lxb*.devops.test' %}
/lustre/testfs:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 755
    - makedirs: true
{% endif %}

lnet_conf:
  file.managed:
    - name: /etc/modprobe.d/lnet.conf
    - contents: 'options lnet networks=tcp(eth0)'
