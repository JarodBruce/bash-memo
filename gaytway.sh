curl -L -o /usr/local/bin/cfssljson https://github.com/cloudflare/cfssl/releases/download/v1.6.5/cfssljson_1.6.5_linux_amd64 && curl -L -o /usr/local/bin/cfssl https://github.com/cloudflare/cfssl/releases/download/v1.6.5/cfssl_1.6.5_linux_amd64 && chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson
wget https://storage.googleapis.com/kubernetes-release/release/v1.21.5/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa

# Install sshpass if not already installed
if ! command -v sshpass &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y sshpass
fi

# Use sshpass to automate the SSH connection
for i in 0 1 2; do sshpass -p 'user' ssh -o StrictHostKeyChecking=no user@controller-$i "sudo mkdir -p /root/.ssh; sudo tee -a /root/.ssh/authorized_keys" < ~/.ssh/id_rsa.pub; done

for instance in worker-0 worker-1 worker-2; do scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/; done
for instance in controller-0 controller-1 controller-2; do
    scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
      service-account-key.pem service-account.pem ${instance}:~/
done

for instance in worker-0 worker-1 worker-2; do
    scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done
for instance in controller-0 controller-1 controller-2; do
  scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${instance}:~/
done

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
for instance in controller-0 controller-1 controller-2; do
  scp encryption-config.yaml ${instance}:~/
done

#実行用Crontabの削除
echo "" | crontab -
