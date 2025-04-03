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
