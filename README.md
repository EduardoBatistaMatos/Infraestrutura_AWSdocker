# Configuração de Infraestrutura AWS
## 1. Criação da VPC

1. Acesse o console da AWS e navegue até o serviço **VPC**.
2. Clique em **Criar VPC** e defina:
   - Click em `VPC and more` para ter uma vpc pré configurada.
   - Nome: `Projeto`
   - IPv4 CIDR Block: `10.0.0.0/16`
   - IPv6 CIDR Block: **Desativado** (ou conforme necessidade)
   - Tenancy : Default
   - Number of Availability Zones (AZs): 2
   - Number of public subnets: 2
   - Number of private subnets: 2
   - NAT gateways ($) : none
   - VPC endpoints: S3 Gateway
   - DNS options: Check enable DNS hostnames and enable DNS resolution

## 2. Criação e Configuração dos Security Groups (SG)

1. No console da AWS, navegue até o serviço de EC2 e acesse **Security Groups**.
2. Crie os seguintes Security Groups:
   - **SG-EC2**: Permitir tráfego de entrada SSH (22), HTTP (80) e HTTPS (443).
   - **SG-EFS**: Permitir tráfego de entrada 2049 (NFS) para o SG-EC2.
   - **SG-RDS**: Permitir tráfego de entrada 3306 (MySQL) apenas do SG-EC2.

## 3. Criação do EFS

1. Acesse **EFS** e clique em **Create file systems**.
2. Defina o nome como `EFS-PROJETO` e escolha a VPC criada previamente.
3. Click em `Customize`.
 - Number of public subnets: 2
 - Number of private subnets: 2


## 4. Criação do RDS

1. Acesse **RDS** e clique em **Criar banco de dados**.
2. Escolha o motor (MySQL/PostgreSQL) e configure:
   - Nome da instância: `rds-projeto`
   - Tipo: `db.t3.micro`
   - Armazenamento: 20GB SSD
   - Conectividade: VPC criada anteriormente
   - Security Group: `SG-RDS`
3. Finalize a criação e anote o endpoint do banco.


## 5. Criação da Instância EC2

1. Acesse **EC2** e clique em **Executar instância**.
2. Escolha:
   - AMI: Amazon Linux 2 / Ubuntu Server
   - Tipo de instância: `t3.micro`
   - VPC e Subnet: conforme configurado
   - Security Group: `SG-EC2`
   - Key Pair: Criar ou usar uma existente
3. Conecte-se à instância via SSH e configure os acessos ao RDS e EFS.
4. Monte o EFS e conecte ao banco de dados.

 
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
```

# Inicia os containers em segundo plano
docker-compose up -d
