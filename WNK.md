### SCP from host -> bastion -> nomad-servers
```bash
scp -o ProxyJump=bastion-meridian ubuntu@10.0.1.20:/home/ubuntu/nomad-install.sh /tmp/file && scp -o ProxyJump=bastion-meridian /tmp/file ubuntu@10.0.1.223:/home/ubuntu/nomad-install.sh
```