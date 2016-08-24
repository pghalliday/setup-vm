#!/bin/bash

set -e

name=$1
user=$2
port=$3

HOSTS=/etc/hosts

SSH=~/.ssh
ID_RSA=$SSH/id_rsa
ID_RSA_PUB=$SSH/id_rsa.pub
CONFIG=$SSH/config
KNOWN_HOSTS=$SSH/known_hosts

USER_HOME=/home/$user
USER_SSH=$USER_HOME/.ssh
USER_ID_RSA=$USER_SSH/id_rsa
USER_ID_RSA_PUB=$USER_SSH/id_rsa.pub
USER_AUTHORIZED_KEYS=$USER_SSH/authorized_keys
USER_KNOWN_HOSTS=$USER_SSH/known_hosts

ROOT_HOME=/root
ROOT_SSH=$ROOT_HOME/.ssh
ROOT_ID_RSA=$ROOT_SSH/id_rsa
ROOT_ID_RSA_PUB=$ROOT_SSH/id_rsa.pub
ROOT_AUTHORIZED_KEYS=$ROOT_SSH/authorized_keys
ROOT_KNOWN_HOSTS=$ROOT_SSH/known_hosts

PROJECTS=$USER_HOME/projects
DOTFILES_SCRIPTS_REPO=git@github.com:pghalliday-dotfiles/scripts.git
DOTFILES=$PROJECTS/pghalliday-dotfiles
DOTFILES_SCRIPTS=$DOTFILES/scripts
TERMINAL_SETUP=$DOTFILES_SCRIPTS/terminal-setup.sh

################
# Local config #
################

# Add the SSH config entry
if ! grep "^Host $name$" $CONFIG; then
  mkdir -p $SSH
  chmod 0700 $SSH
  cat >> $CONFIG << END_CONFIG

Host $name
  HostName $name
  User $user
  Port $port
END_CONFIG
fi

# Add a hosts entry (will prompt for local password)
if ! grep " $name " $HOSTS; then
  sudo sed -i '' -e "/^127.0.0.1[[:space:]]/s/$/ $name /" $HOSTS
fi

if ! grep "[$name]" $KNOWN_HOSTS; then
  # Add VM to known hosts to prevent prompt later
  ssh-keyscan -p 2222 -f- >> $KNOWN_HOSTS << EOH
127.0.0.1 $name
EOH
fi

#################################
# VM SSH configuration for user #
#################################

# Configure VM SSH keys (will prompt for VM password)
ssh $name << --END_SCRIPT--
mkdir -p $USER_SSH
chmod 0700 $USER_SSH
cat > $USER_ID_RSA << --END_PRIVATE_KEY--
$(cat $ID_RSA)
--END_PRIVATE_KEY--
chmod 0600 $USER_ID_RSA
cat > $USER_ID_RSA_PUB << --END_PUBLIC_KEY--
$(cat $ID_RSA_PUB)
--END_PUBLIC_KEY--
cp $USER_ID_RSA_PUB $USER_AUTHORIZED_KEYS
chmod 0600 $USER_AUTHORIZED_KEYS
--END_SCRIPT--

# Set sudo to be passwordless for user (will prompt for VM password)
ssh -t $name "sudo sh -c \"echo '$user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$user\""

###########################################################
# Setup known hosts here before copying SSH setup to root #
###########################################################

# Required for cloning from github without prompt
if ! ssh $name grep "[github.com]" $USER_KNOWN_HOSTS; then
  ssh $name "ssh-keyscan github.com >> $USER_KNOWN_HOSTS"
fi

###################################
# copy SSH setup to the root user #
###################################

ssh $name << END_SCRIPT
sudo sh << END_ROOT_SCRIPT
mkdir -p $ROOT_SSH
chmod 0700 $ROOT_SSH
cp $USER_ID_RSA $ROOT_ID_RSA
cp $USER_ID_RSA_PUB $ROOT_ID_RSA_PUB
cp $USER_AUTHORIZED_KEYS $ROOT_AUTHORIZED_KEYS
cp $USER_KNOWN_HOSTS $ROOT_KNOWN_HOSTS
END_ROOT_SCRIPT
END_SCRIPT

###############################
# Distribution specific stuff #
###############################

if ssh $name "hash add-apt-repository 2>/dev/null"; then
  # Ubuntu

  # Install latest git
  ssh $name "sudo add-apt-repository ppa:git-core/ppa -y && sudo apt-get update -y && sudo apt-get install git -y"
else
  echo "Unsupported distribution!"
  exit 1
fi

##################
# Setup dotfiles #
##################

ssh $name << END_SCRIPT
if [ -d $DOTFILES_SCRIPTS ]; then
  git -C $DOTFILES_SCRIPTS pull
else
  git clone $DOTFILES_SCRIPTS_REPO $DOTFILES_SCRIPTS
fi
$TERMINAL_SETUP
END_SCRIPT
