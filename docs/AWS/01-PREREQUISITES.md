# Prerequisites - Gathering Your Tools

**⏱️ Time: 30 minutes**

**The Story**: Before you can build your cloud city, you need to gather your tools and get a construction permit. Think of this like preparing for a big DIY project - you need the right tools, permits, and understanding before you start! 🛠️

This section covers everything you need to install and configure before deploying PayFlow infrastructure.

---

## 1. AWS Account Setup (Getting Your Construction Permit)

**The Story**: You can't build in AWS without an AWS account. It's like getting a permit to build in a new city.

**Create AWS Account**:
1. Go to https://aws.amazon.com/
2. Create account (requires credit card - like a deposit)
3. **IMPORTANT**: Set up billing alerts immediately!

**Why Credit Card?** AWS charges for what you use. Think of it like a utilities bill - you only pay for what you consume. But you need a card on file.

### 🚨 Set Up Billing Alerts (The Smoke Detector Story)

**The Story**: Imagine you leave your lights on while on vacation. Without a smoke detector (billing alert), you won't know until you get a huge bill! 

**Set up billing alerts to prevent surprise bills**:
```bash
# Create SNS topic for billing alerts (like installing a smoke detector)
aws sns create-topic --name billing-alerts

# Subscribe with your email (like connecting the alarm to your phone)
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:billing-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Create CloudWatch alarm for billing (like setting the alarm threshold)
aws cloudwatch put-metric-alarm \
  --alarm-name billing-alert \
  --alarm-description "Alert when AWS charges exceed $50" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold
```

**Why This Matters**: AWS charges can add up quickly if you forget to destroy resources. This alert is like a smoke detector - it warns you before things get expensive!

**Real-World Analogy**: 
- Without alert: Like getting a $500 electricity bill at the end of the month 😱
- With alert: Like getting a text when your bill hits $50 😊

---

## 2. Install Tools (Getting Your Toolbox)

**The Story**: You need three main tools to build your cloud infrastructure:
1. **Terraform** - Like a blueprint system and construction manager
2. **AWS CLI** - Like a walkie-talkie to communicate with AWS
3. **kubectl** - Like a remote control for your applications

Let's install them one by one!

### Terraform (The Blueprint System)

**What It Is**: Terraform is Infrastructure as Code. Think of it like building with LEGO instructions instead of free-hand - you write down exactly what you want, and Terraform builds it.

**macOS** (The Mac Way):
```bash
brew install terraform
terraform version  # Should show >= 1.6.0
```

**Linux** (The Linux Way):
```bash
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version
```

**What This Does**: Installs Terraform so you can write and run infrastructure code.

**Analogy**: Like installing AutoCAD so you can design buildings (infrastructure).

---

### AWS CLI (The Walkie-Talkie)

**What It Is**: AWS CLI lets you talk to AWS from your computer. Like a walkie-talkie between you and AWS.

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify it works
aws --version
aws configure  # Enter your AWS credentials
```

**What This Does**: Installs AWS CLI so you can run AWS commands from your terminal.

**Analogy**: Like installing a phone app to control your smart home - but for AWS!

---

### kubectl (The Kubernetes Remote Control)

**What It Is**: kubectl is how you control Kubernetes clusters. Think of it like a TV remote, but for your applications.

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

**What This Does**: Installs kubectl so you can manage your Kubernetes clusters.

**Analogy**: Like installing a remote control app for your smart TV - but for your apps in Kubernetes!

---

## 3. Configure AWS CLI (Proving Your Identity)

**The Story**: Now that you have the AWS CLI installed, you need to prove who you are. This is like showing your ID at the construction site.

```bash
aws configure
# You'll be asked for:
# AWS Access Key ID: [Enter your access key]
# AWS Secret Access Key: [Enter your secret key]
# Default region name: us-east-1
# Default output format: json

# Verify configuration (like checking your ID is valid)
aws sts get-caller-identity
```

**What This Does**: Configures AWS CLI with your credentials so it knows who you are.

**Why This Matters**: Terraform needs AWS credentials to create resources. AWS CLI uses the same credentials, so once configured here, Terraform can use them too.

**Analogy**: 
- AWS Access Keys = Your ID card
- AWS CLI configure = Showing your ID to security
- Terraform = Uses the same ID automatically

**Where to Get Credentials**: 
1. AWS Console → IAM → Users → Your User → Security Credentials
2. Create Access Key
3. Copy Access Key ID and Secret Access Key
4. ⚠️ **Save them securely!** You won't see the secret key again.

---

## 4. Create SSH Key Pair (Getting Your Security Key)

**The Story**: You'll need to access your bastion host (the security gate) via SSH. This is like getting a key card for the building.

```bash
# Generate key pair (like getting a key card made)
ssh-keygen -t rsa -b 4096 -f payflow-bastion.pem -N ""

# Create AWS key pair (registering the key card with AWS)
aws ec2 create-key-pair \
  --key-name payflow-bastion \
  --query 'KeyMaterial' \
  --output text > payflow-bastion.pem

# Set permissions (like activating the key card - required for SSH)
chmod 400 payflow-bastion.pem

# Verify (checking your key card is registered)
aws ec2 describe-key-pairs --key-names payflow-bastion
```

**What This Does**: Creates an SSH key pair that lets you securely access your bastion host.

**Why You Need This**: You'll need SSH access to the bastion host to reach private EKS clusters. Think of it like needing a key card to enter the secure building.

**Security Note**: The `.pem` file is like your house key - keep it secure! Don't share it or commit it to git.

x**✨ Bonus: IP Auto-Detection**:
- **Good News**: You don't need to manually get your IP address!
- Terraform will automatically detect your public IP during deployment
- Just leave `bastion_allowed_cidrs = []` in `terraform.tfvars`
- Terraform handles it for you! 🎉

**Analogy**:
- SSH Key = Your key card for the building
- Bastion Host = The security gate that needs your key card
- Private EKS = The secure area you can only access via the gate
- IP Auto-Detection = The security system automatically recognizes you!

---

## 5. Verify Everything Works (The Tool Check)

**The Story**: Before starting construction, let's make sure all your tools work. This is like testing your drill, saw, and hammer before building.

```bash
# Test AWS access (checking your walkie-talkie works)
aws sts get-caller-identity
# Should show your AWS account ID and user name

# Test Terraform (checking your blueprint system works)
terraform version
# Should show version >= 1.6.0

# Test kubectl (checking your remote control works)
kubectl version --client
# Should show client version

# Test SSH key (checking your key card exists)
ls -la payflow-bastion.pem
# Should show the file with permissions -r--------
```

**If any command fails**, fix it before proceeding. You'll need all tools working.

**The Importance**: It's like checking all your tools before starting a DIY project. If your drill doesn't work when you're halfway through, you're stuck!

**Common Issues**:
- **AWS CLI not configured**: Run `aws configure` again
- **Terraform not found**: Make sure it's in your PATH
- **kubectl not found**: Make sure it's installed and in your PATH
- **SSH key not found**: Re-run the key creation steps

---

## ✅ Ready to Build?

**The Checklist** (Your Pre-Flight Check):
- [ ] AWS account created (construction permit ✅)
- [ ] Billing alerts set up (smoke detector ✅)
- [ ] Terraform installed (blueprint system ✅)
- [ ] AWS CLI installed (walkie-talkie ✅)
- [ ] kubectl installed (remote control ✅)
- [ ] AWS CLI configured (identity verified ✅)
- [ ] SSH key created (key card ✅)
- [ ] All tools verified (tools tested ✅)

**If everything checks out, you're ready to start building!** 🚀

**Next Step**: Understand the architecture before building → [Next: Understand Architecture](./02-UNDERSTAND-FIRST.md)

**Why Understand First?** It's like reading the blueprint before starting construction. Understanding the "why" will save you hours of confusion later!
