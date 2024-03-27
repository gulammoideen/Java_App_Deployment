resource "aws_security_group" "security_group" {
  name = "devSecOps"
  vpc_id = aws_vpc.main.id
  ingress {
    description = "Allow HTTP Requests"
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTPS Requests"
    from_port = "443"
    to_port = "443"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH Requests"
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "any"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "devSecOpsSG"
  }
}
resource "aws_key_pair" "key_pair" {
  key_name = "devsecops"
  public_key = file("~/.ssh/id_rsa.pub")
}
resource "aws_iam_policy" "eks_full_access_policy" {
  name        = "eks_full_access_policy"
  description = "Policy granting full access to Amazon EKS"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "eks_instance_role" {
  name               = "eks_instance_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "EKS Instance Role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_instance_role_policy_attachment" {
  role       = aws_iam_role.eks_instance_role.name
  policy_arn = aws_iam_policy.eks_full_access_policy.arn
}
resource "aws_iam_instance_profile" "eks_instance_profile" {
  name = "eks_instance_profile"
  role = aws_iam_role.eks_instance_role.name
}

variable "access_key" {
  default = "__ACCESSKEY__"
}
variable "secret_key" {
  default = "__SECRETKEY__"
}
variable "aws_region" {
  default = "__AWSREGION__"
}
resource "aws_instance" "Jumphost_server" {
  ami = "ami-0261755bbcb8c4a84"
  instance_type = "t2.micro"
  key_name = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [aws_security_group.security_group.id]
  iam_instance_profile = aws_iam_instance_profile.eks_instance_profile.name
  subnet_id = aws_subnet.public_us_east_1a.id
  availability_zone = "us-east-1a"
  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host = self.public_ip
  }
  provisioner "file" {
    source = "deployment.yaml"
    destination = "/home/ubuntu/deployment.yaml" 
  }

  provisioner "file" {
    source = "~/.ssh/id_rsa"
    destination = "/home/ubuntu/.ssh/id_rsa"
  }
  provisioner "remote-exec" {
    inline = [ 
        "echo 'Executing to remote instance'",
        "sudo apt-add-repository ppa:ansible/ansible -y",
        "sudo apt-get update -y",
        "sudo apt install python3-pip -y ",
        "sudo pip3 install awscli",
        "aws configure set aws_access_key_id ${var.access_key}",
        "aws configure set aws_secret_access_key ${var.secret_key}",
        "aws configure set region ${var.aws_region}",
        "curl -LO https://dl.k8s.io/release/v1.22.3/bin/linux/amd64/kubectl",
        "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl",
        "aws eks update-kubeconfig --name ${aws_eks_cluster.zocket.name} --region ${var.aws_region}",
        "kubectl apply -f /home/ubuntu/deployment.yaml"
     ]
  }
  #depends_on = [ aws_eks_cluster.zocket , aws_eks_node_group.private_nodes ]
}