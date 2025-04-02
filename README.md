# Configuração de Infraestrutura AWS

## 1. Criação da VPC

1. Acesse o console da AWS e navegue até o serviço **VPC**.
2. Clique em **Criar VPC** e defina:  
   - Clique em `VPC and more` para ter uma VPC pré-configurada.  
   - **Nome**: `Projeto`  
   - **IPv4 CIDR Block**: `10.0.0.0/16`  
   - **IPv6 CIDR Block**: **Desativado** (ou conforme necessidade)  
   - **Tenancy**: `Default`  
   - **Number of Availability Zones (AZs)**: `2`  
   - **Number of Public Subnets**: `2`  
   - **Number of Private Subnets**: `2`  
   - **NAT Gateways ($)**: `None`  
   - **VPC Endpoints**: `S3 Gateway`  
   - **DNS Options**: `Check Enable DNS Hostnames` e `Enable DNS Resolution`  


## 2. Criação e Configuração dos Security Groups (SGs)

1. No console da AWS, navegue até o serviço de EC2 e acesse **Security Groups**.
2. Crie os seguintes Security Groups:
   - **SG-EC2**: Permitir tráfego de entrada SSH (22) para My IP e HTTP (80) para o SG-CLB.
   - **SG-CLB**: Permitir trafego de entreda HTTP (80) para o My IP e trafego de saida HTTP (80) para o SG-EC2
   - **SG-EFS**: Permitir tráfego de entrada 2049 (NFS) para o SG-EC2.
   - **SG-RDS**: Permitir tráfego de entrada 3306 (MySQL) apenas do SG-EC2.

## 3. Criação do EFS

1. Acesse **EFS** e clique em **Create file systems**.
2. Defina o nome como `EFS-PROJETO` e escolha a VPC criada previamente.
3. Click em `Customize`.
 - File system type: Regional
 - Transition into Infrequent Access (IA): None
 - Transition into Archive: None
 - Throughput mode: Bursting
 - Subnet ID: Selecione as subnets publicas.
 - Security groups: SG-EFS

## 4. Criação do RDS
1. Click em **Subnet groups** e depois em **Create DB subnet group**.
     - Name: DB_Subnet_Group.
     - VPC: Selecione a VPC criada previamente.
     - Availability Zones: us-east-1a e us-east-1b.
     - Subnets: selecione todas as subnets.
       
3. Ainda no **RDS** clique em databases e **Create database**.
   - Choose a database creation method: Standard create
   - Engine options: MySQL
   - Templates: Free tier
   - Availability and durability: Single-AZ DB instance deployment (1 instance)
   - DB instance identifier: (nome da instancia)
   - Master username: (nome do usuario master)
   - Credentials management: Self managed
   - Master password: (senha do usuario master)
   - Tipo: `db.t3.micro`
   - Storage type: General Purpose SSD (gp3)
   - Armazenamento: 20GB SSD
   - Connectivity: Don’t connect to an EC2 compute resource
   - Conectividade: VPC criada anteriormente
   - DB subnet group: selecione o DB subnet group criado previamente
   - Public access: No
   - VPC security group (firewall): Choose existing
   - Existing VPC security groups: SG-RDS
   - Database authentication: Password authentication
   - Monitoring: Database Insights - Standard
   - Initial database name: nomeDB

## 5. Criação da Instância EC2

1. Acesse **EC2** e clique em **Launch instances**.
2. Escolha:
   - AMI: Amazon Linux 2023
   - Instance type: `t2.micro`
   - VPC e Subnet: conforme configurado
   - Security Group: `SG-EC2`
   - Key pair: Click em **Create key pair**
        * Escolha um nome para sua key pair e selecione o tipo RSA com formato .ppk.
   - VPC: selecione a VPC criada anteriormente.
   - Subnet: selecione uma subnet publica.
   - Auto-assign public IP: Enable
   - Firewall (security groups): Select existing security group
   - Common security groups: SG-EC2
   - Configure storage: 1x 8 GiB gp3
   - User data:
           
      ``` sh
      #!/bin/bash
      # Atualiza o sistema operacional
      sudo yum update -y
      
      # Instala o Docker
      sudo yum install -y docker
      sudo systemctl start docker
      sudo systemctl enable docker
      
      # Adiciona o usuário ec2-user ao grupo docker para executar comandos sem sudo
      sudo usermod -aG docker ec2-user
      
      # Aplica a mudança de grupo imediatamente sem necessidade de logout
      newgrp docker
      
      # Verifica se o Docker foi instalado corretamente
      docker --version
      
      # Baixa o Docker Compose na versão mais recente
      sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
      
      # Concede permissão de execução ao Docker Compose
      sudo chmod +x /usr/local/bin/docker-compose
      
      # Verifica se o Docker Compose foi instalado corretamente
      docker-compose version
      
      # Cria o diretório do projeto
      sudo mkdir -p /projeto
      
      # Cria o diretório onde o EFS será montado
      mkdir /efs
      
      # Instala o cliente do Amazon EFS
      sudo yum install -y amazon-efs-utils
      
      # Monta o sistema de arquivos EFS no diretório /efs
      sudo mount -t efs -o tls <ID_DO_RDS>:/ efs
      
      # Acessa o diretório do projeto
      cd /projeto
      
      # Cria o arquivo docker-compose.yml com as configurações do WordPress
      cat <<EOF > docker-compose.yml
      version: '3.8'
      
      services:
        wordpress:
          image: wordpress:latest
          container_name: wordpress_app
          restart: always
          ports:
            - "80:80"
          environment:
            WORDPRESS_DB_HOST: <EndPointBD>
            WORDPRESS_DB_NAME: <NomeBD>
            WORDPRESS_DB_USER: <UserDB>
            WORDPRESS_DB_PASSWORD: <PasswordDB>
          volumes:
            - /efs:/var/www/html  # Monta o EFS no diretório do WordPress
          networks:
            - wp_network
      
      volumes:
        wordpress_data:
      
      networks:
        wp_network:
      EOF
      
      # Inicia os containers em segundo plano
      docker-compose up -d
      ```
      
3. Conecte-se à instância via SSH e teste a aplicação.


## 6. Criação do **CLB (Classic Load Balancer)**  

1. Acesse o serviço **Load Balancer** e clique em **Create Load Balancer**.  
2. Selecione o tipo **ALB**.  
3. Configure as seguintes opções:  
   - **Load Balancer Name**: `<nome do ALB>`  
   - **Scheme**: `Internet-facing`  
   - **Availability Zones and Subnets**: Selecione as duas zonas públicas de disponibilidade.  
   - **Security Groups**: `SG-ALB`  
   - **Listeners and Routing**:  
     - **Listener Protocol**: `HTTP 80`  
     - **Instance Protocol**: `HTTP 80`  
   - **Health Checks**:  
     - **Ping Protocol**: `HTTP 80`  
     - **Ping Path**: `/wp-admin/install.php`  
   - **Instances**: Selecione a instância criada previamente.  

---

## 7. Criação do **Auto Scaling**  

### 7.1. **Criação do Launch Template**  

1. Acesse **Launch Templates** e clique em **Create Launch Template**.  
2. Configure as seguintes opções:  
   - **Launch Template Name**: `<nome do template>`  
   - **Template Version Description**: `1.0.0`  
   - **Auto Scaling Guidance**: `Check`  
   - **Application and OS Images (Amazon Machine Image - AMI)**: `Amazon Linux 2023`  
   - **Instance Type**: `t2.micro`  
   - **Key Pair (Login)**: Selecione a **KeyPair** criada previamente.  
   - **Network Settings**:  
     - **Subnet**: `Don't include in launch template`  
     - **Firewall (Security Groups)**: `Select existing security group`  
     - **Security Group**: `SG-EC2`  
   - **Tags**: Adicione conforme necessidade.  
   - **Advanced Details**:  
     - **User Data**: Edite os dados de conexão conforme listado no **README**.  

---

### 7.2. **Criação do Auto Scaling Group**  

1. Acesse **Auto Scaling Groups** e clique em **Create Auto Scaling Group**.  
2. Configure as seguintes opções:  
   - **Auto Scaling Group Name**: `<nome do AS>`  
   - **Launch Template**: Selecione o **Launch Template** criado previamente.  
   - **Version**: `Default`  
   - **VPC**: Selecione a **VPC** criada anteriormente.  
   - **Availability Zones and Subnets**: Selecione as duas zonas públicas.  
   - **Availability Zone Distribution**: `Balanced best effort`  
   - **Load Balancing**: `Attach to an existing load balancer`  
   - **Attach to an existing Load Balancer**:  
     - **Classic Load Balancers**: Selecione o **Load Balancer** criado.  
     - **Existing Load Balancer Target Groups**: `<nome do TG>`  
   - **VPC Lattice Integration Options**: `No VPC Lattice Service`  
   - **Health Checks**:  
     - **Turn on Elastic Load Balancing Health Checks**  
     - **Health Check Grace Period**: `300`  
   - **Scaling Configuration**:  
     - **Desired Capacity**: `2`  
     - **Min Desired Capacity**: `2`  
     - **Max Desired Capacity**: `4`  
   - **Automatic Scaling**:  
     - **Target Tracking Scaling Policy**  
     - **Scaling Policy Name**: `Target Tracking Policy`  
     - **Metric Type**: `Average CPU Utilization`  
     - **Target Value**: `85`  
     - **Instance Warmup**: `300`  
     - **Instance Maintenance Policy**: `No policy`  
     - **Additional Capacity Settings**: `Default`  
     - **Additional Settings**: `Check Enable Group Metrics Collection within CloudWatch`  

---

## 8. Criando um Alarme no **CloudWatch** para Notificações via E-mail  

1. Acesse **CloudWatch** e clique em **Alarms**.  
2. Clique em **Create Alarm**.  
3. Configure a métrica:  
   - **Select Metric** → `EC2` → `CPUUtilization`  
   - **Metric Name**: `CPUUtilization`  
   - **AutoScalingGroupName**: `ASG_Projeto`  
   - **Statistic**: `Average`  
   - **Period**: `1 minute`  
   - **Threshold Type**: `Static`  
   - **Whenever CPUUtilization is**: `Greater/Equal`  
   - **Threshold**: `80`  
   - **Alarm State Trigger**: `In alarm`  
   - **Send a Notification to the Following SNS Topic**: `Create new topic`  
   - **Create a New Topic**: `<nome do tópico>`  
   - **Email Endpoints That Will Receive the Notification**: `<seuemail@seuemail.com>`  
4. Clique em **Create**.  
5. **Alarm Name**: `<Nome do Alarme>`  
6. Clique em **Create** e confirme no e-mail de verificação (`<seuemail@seuemail.com>`).  

---

## 9. Testando a Aplicação  

1. Acesse **Load Balancer** e copie o **DNS Name**.  
2. Cole o **DNS** no navegador e verifique se a página do **WordPress** está acessível.  

### **Verificando o Funcionamento do Auto Scaling**  

1. Delete uma instância e veja outra sendo criada automaticamente.  
2. Teste via terminal Linux das instâncias:  
   - Instale o **stress-ng**:  
     ```bash
     sudo yum install stress-ng -y
     ```  
   - Execute o seguinte comando para simular carga na CPU:  
     ```bash
     stress-ng --cpu 4 --cpu-load 100 --timeout 600s --temp-path /tmp
     ```  
3. Esse teste gerará uma notificação por e-mail para `<seuemail@seuemail.com>` e o **Auto Scaling** criará novas instâncias automaticamente.  
