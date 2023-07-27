#!/bin/bash

main_function() {
USER='opc'

# Resize root partition
printf "fix\n" | parted ---pretend-input-tty /dev/sda print
VALUE=$(printf "unit s\nprint\n" | parted ---pretend-input-tty /dev/sda |  grep lvm | awk '{print $2}' | rev | cut -c2- | rev)
printf "rm 3\nIgnore\n" | parted ---pretend-input-tty /dev/sda
printf "unit s\nmkpart\n/dev/sda3\n\n$VALUE\n100%%\n" | parted ---pretend-input-tty /dev/sda
pvresize /dev/sda3
pvs
vgs
lvextend -l +100%FREE /dev/mapper/ocivolume-root
xfs_growfs -d /

sudo dnf install wget git python3.11 python3.11-devel.x86_64 libsndfile rustc cargo unzip zip git git-lfs jq -y

# Opensearch
su -c "wget -O /home/$USER/opensearch-2.8.0-linux-x64.tar.gz https://artifacts.opensearch.org/releases/bundle/opensearch/2.8.0/opensearch-2.8.0-linux-x64.tar.gz" $USER
su -c "tar xvzf /home/$USER/opensearch-2.8.0-linux-x64.tar.gz -C /home/$USER/" $USER
su -c "sed -i 's/Xms1g/Xms4g/g' /home/$USER/opensearch-2.8.0/config/jvm.options" $USER
su -c "sed -i 's/Xmx1g/Xmx4g/g' /home/$USER/opensearch-2.8.0/config/jvm.options" $USER
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -p

cat <<EOT > /etc/systemd/system/opensearch.service
[Unit]
Description=Instance to serve opensearch
[Service]
ExecStart=/bin/bash /home/$USER/opensearch-2.8.0/opensearch-tar-install.sh
User=$USER
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOT

# App source
su -c "git clone https://github.com/carlgira/oci-tf-document-qna /home/$USER/oci-tf-document-qna" $USER
HF_TOKEN=`curl -L http://169.254.169.254/opc/v1/instance/ | jq -r '.metadata."hf_token"'`
su -c "sed -i 's/HF_TOKEN/$HF_TOKEN/g' /home/$USER/oci-tf-document-qna/app/start-gradio.sh" $USER
su -c "sed -i 's/HF_TOKEN/$HF_TOKEN/g' /home/$USER/oci-tf-document-qna/app/start-gradio.sh" $USER

# Gradio web UI
cat <<EOT >> /etc/systemd/system/gradio.service
[Unit]
Description=systemd service start gradio

[Service]
Environment="python_cmd=python3.11"
Environment="pip_cmd=pip"
ExecStart=/bin/bash /home/$USER/oci-tf-document-qna/app/start-gradio.sh
User=$USER
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOT

# Flask services
cat <<EOT >> /etc/systemd/system/flask.service
[Unit]
Description=systemd service start flask

[Service]
Environment="python_cmd=python3.11"
Environment="pip_cmd=pip"
ExecStart=/bin/bash /home/$USER/oci-tf-document-qna/app/start-flask.sh
User=$USER
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable gradio flask opensearch
systemctl start gradio flask opensearch


firewall-cmd --zone=public --add-port=3000/tcp --permanent
firewall-cmd --zone=public --add-port=7860/tcp --permanent
firewall-cmd --reload
}

main_function 2>&1 >> /var/log/startup.log
