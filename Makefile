# -u tests/minimal_init.vim
# nvim --headless -c "PlenaryBustedDirectory tests/plenary/ {minimal_init = 'tests/minimal_init.vim'}"
test:
	nvim --headless -c "PlenaryBustedDirectory tests/plenary/"
