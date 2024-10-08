# PS1 prompt
export PS1='\[\e[91;1m\]\u\[\e[0m\]@\[\e[92;1m\]${HOSTNAME}\[\e[0m\] \w # '

# Aliases
alias l='ls --color=auto -Alh'
alias v='vi'

# Function for loading/unloading device driver kernel module
c()
{
	if [ -z "$(lsmod | grep cco)" ]; then
		# Module is not loaded, load it
		modprobe cco
    else
		# Module is already loaded, unload it
		modprobe -r cco
    fi
}
