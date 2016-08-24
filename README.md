# setup-vm

Script to initialize a new VM the way I like it

## Usage

Assuming the new VM is running an SSH server and is NAT'ed with the SSH port forwarded

```
./setup-vm.sh NAME USER SSH_PORT
```

This will

- create an entry called NAME in the local SSH config
- add a hosts entry for NAME
- upload `~/.ssh/id_rsa` to the VM
- upload `~/.ssh/id_rsa.pub` to the VM and set it as the `authorized_keys` file
- copy SSH config to root user
- Install the latest version of `git`
- Set up dot files using https://github.com/pghalliday-dotfiles/scripts

Currently supports the following distributions

- Ubuntu
