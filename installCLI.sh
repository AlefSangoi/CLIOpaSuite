#!/bin/bash

# Função para verificar CPU, Memória e Disco
verificar_sistema() {
  echo "===== Verificação do Sistema ====="
  
  # CPU: Mostra o número de CPUs
  echo "CPU:"
  grep -c ^processor /proc/cpuinfo
  echo "núcleos de CPU disponíveis."
  echo ""
  
  # Memória: Mostra o total e o usado de forma resumida
  echo "Memória Utilizada:"
  free -h | awk '/Mem/ {print "Usado: " $3 " / Total: " $2}'
  echo ""
  
  # Disco: Mostra o total e o uso de disco
  echo "Uso de Disco:"
  df -h --total | awk '/total/ {print "Usado: " $3 " / Total: " $2}'
  echo "==================================="
  echo ""
}

# Função para atualizar o sistema
atualizar_sistema() {
  echo "Atualizando o sistema..."
  apt update -y && apt upgrade -y
}

# Função para instalar pacotes e Opa Suite
instalar_opasuite() {
  echo "Instalando pacotes necessários..."
  apt update -y && apt install curl -y && apt install bash-completion -y

  echo "Baixando e instalando o Opa Suite..."
  curl -L -s -o /usr/local/bin/opasuite https://atualizacoes.ixcsoft.com.br/atualizacoes/OpaSuite/debian12/opasuite && \
  chmod +x /usr/local/bin/opasuite && \
  opasuite completion bash > /root/.opasuite_completion && \
  source /root/.opasuite_completion

  # Adiciona a linha no ~/.bashrc para bash-completion
  echo "Configurando bash completion para o Opa Suite..."
  if ! grep -Fxq ". /etc/bash_completion" ~/.bashrc; then
    echo "if [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi" >> ~/.bashrc
  fi

  # Recarrega o bash automaticamente
  source ~/.bashrc
}

# Função para instalar o Opa Suite com código e senha
instalar_opasuite_com_credenciais() {
  read -p "Qual o seu código Opa Suite: " CODIGO
  read -sp "Digite a sua senha Opa Suite: " SENHA
  echo ""

  # Executa o comando para instalar o Opa Suite
  echo "Instalando Opa Suite com o código e senha fornecidos..."
  opasuite install -a -c "$CODIGO" "$SENHA"
}

# Função para configurar a pasta SIP
configurar_pasta_sip() {
  echo "Renomeando o arquivo sip.conf para Oldsip.conf..."
  if [ -f /etc/asterisk/sip.conf ]; then
    mv /etc/asterisk/sip.conf /etc/asterisk/Oldsip.conf
    echo "Arquivo sip.conf renomeado para Oldsip.conf."
  fi

  echo "Criando um novo arquivo sip.conf..."

  # Criação do arquivo sip.conf com o conteúdo atualizado
  cat <<EOL > /etc/asterisk/sip.conf
[codec](!)
disallow     = all
allow        = ulaw
allow        = alaw
allow        = gsm
allow        = g729
allow        = ilbc
allow        = speex
videosupport = yes
textsupport  = yes

[rtp](!)
rtcachefriends = yes
rtsavepath     = yes
rtsavesysname  = yes
rtupdate       = yes
rtautoclear    = no

[jitter_buffer](!)
jbenable          = yes
jbforce           = no
jbmaxsize         = 200
jbresyncthreshold = 1000
jbimpl            = fixed
jblog             = no

[contexto](!)
context = default

[nat](!)
nat = force_rport,comedia

[qualify](!)
qualify = yes

[localnet](!)
localnet = 100.64.0.0/255.192.0.0
localnet = 10.0.0.0/255.0.0.0
localnet = 172.16.0.0/255.240.0.0
localnet = 192.168.0.0/255.255.0.0
localnet = 127.0.0.0/255.0.0.0
localnet = 169.254.0.0/255.255.0.0
externip = ip_do_servidor

[seguranca](!)
acl = opasuite
directmediaacl = opasuite

[dtmf](!)
dtmf              = rfc2833
dtmfmode          = rfc2833
relaxdtmf         = yes
rfc2833compensate = yes

[tls](!)
encryption    = yes
tlsbindaddr   = 0.0.0.0:6091
tlsenable     = yes
tlscapath     = /
tlscertfile   = /etc/asterisk/keys/opasuite.pem
tlsprivatekey = /etc/asterisk/keys/opasuite.key
tlscafile     = /etc/asterisk/keys/opasuite_ca.crt
tlsdontverifyserver = no

[transporte](!)
transport = udp,ws,wss,tls

[dtls](!)
dtlsenable     = yes
dtlsverify     = fingerprint
dtlssetup      = actpass
dtlscertfile   = /etc/asterisk/keys/opasuite.pem
dtlsprivatekey = /etc/asterisk/keys/opasuite.key
dtlscafile     = /etc/asterisk/keys/opasuite_ca.crt

[opasuite](!,contexto,codec)
encryption   = yes
avpf         = yes
force_avp    = yes
icesupport   = yes
directmedia  = no
dtlsenable   = yes
dtlsverify   = fingerprint
dtlscertfile = /etc/asterisk/keys/opasuite.pem
dtlscafile   = /etc/asterisk/keys/opasuite_ca.crt
dtlssetup    = actpass
rtcp_mux     = yes

[general](dtmf,tls,contexto,localnet,rtp,nat,codec,qualify,transporte)
type        = friend
pedantic    = no
udpbindaddr = [::]:6090
tcpenable   = yes
tcpbindaddr = [::]:6090
allowguest  = no

language    = pt_BR
icesupport  = yes
host        = dynamic
callcounter = yes

#include "sip/register/*.conf"
#include "sip/peers/*.conf"
#include "sip/trunk/*.conf"
EOL

  echo "Novo arquivo sip.conf criado com sucesso!"
}

# Função para listar os usuários com acesso root
listar_usuarios_root() {
    echo "Usuários com acesso root:"
    awk -F: '($3 == 0) {print $1}' /etc/passwd
}

# Função para listar os usuários que podem fazer login no sistema
listar_usuarios_com_login() {
    echo "===== Usuários com permissão para login ====="
    awk -F: '$7 ~ /(bash|sh)/ {print $1}' /etc/passwd
    echo "============================================="
}

# Função para inativar o acesso de um usuário
inativar_usuario() {
    local usuario=$1

    # Verificar se o usuário existe
    if id "$usuario" &>/dev/null; then
        echo "Inativando o usuário: $usuario"

        # Desativar o usuário
        usermod -L "$usuario"

        echo "Usuário $usuario foi inativado."
    else
        echo "Usuário $usuario não encontrado!"
        exit 1
    fi
}

# Execução do script
clear
echo "===== Verificação de Usuários ====="

# Listar os usuários com permissão para login
listar_usuarios_com_login

# Perguntar qual usuário deseja inativar
read -p "Digite o nome do usuário que deseja inativar: " usuario_inativar

# Inativar o usuário
inativar_usuario "$usuario_inativar"

echo "Script concluído com sucesso!"

# Função para reiniciar o serviço SSH
reiniciar_ssh() {
    echo "Reiniciando o serviço SSH..."
    systemctl restart ssh
    echo "Serviço SSH reiniciado."
}

# Execução do script
clear
echo "===== Bem-vindo ao Script de Configuração do Debian 12 ====="

# Verificar CPU, Memória e Disco
verificar_sistema

# Atualizar o sistema
atualizar_sistema

# Instalar pacotes e Opa Suite
instalar_opasuite

# Solicitar a instalação do Opa Suite com credenciais
read -p "Deseja instalar o Opa Suite com código e senha? (1 para Sim / 2 para Não): " opcao_opasuite
if [ "$opcao_opasuite" -eq 1 ]; then
  instalar_opasuite_com_credenciais
fi

# Configurar a pasta SIP
read -p "Deseja configurar a pasta SIP? (1 para Sim / 2 para Não): " opcao_sip
if [ "$opcao_sip" -eq 1 ]; then
  configurar_pasta_sip
fi

# Listar usuários com acesso root
listar_usuarios_root

# Perguntar qual usuário inativar no acesso root
read -p "Digite o nome do usuário que deseja inativar o acesso root: " usuario_inativar
inativar_usuario "$usuario_inativar"

# Reiniciar o serviço SSH
reiniciar_ssh

echo "===== Script Finalizado ====="
