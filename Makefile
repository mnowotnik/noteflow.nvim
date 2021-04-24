
# TODO:
# - lint
# - format

.PHONY: demo

vim=DEBUG_NOTEFLOW=true nvim --noplugin -u tests/minimal_init.vim --headless

test: deps
	$(vim) -c "PlenaryBustedDirectory tests/plenary/ {minimal_init = 'tests/minimal_init.vim'}"

deps:
	mkdir deps
	cd deps && git clone --depth 1 https://github.com/nvim-lua/plenary.nvim
	cd deps && git clone --depth 1 https://github.com/nvim-telescope/telescope.nvim
	cd deps && git clone --depth 1 https://github.com/nvim-lua/popup.nvim

ci-test: github-actions-setup.sh
	bash -c 'source github-actions-setup.sh nightly-x64 && make test'

github-actions-setup.sh:
	curl -OL https://raw.githubusercontent.com/norcalli/bot-ci/master/scripts/github-actions-setup.sh

clean:
	rm -rf deps

testfile: deps
	$(vim) -c "PlenaryBustedFile $(testfile)"

demo: deps
	XDG_CONFIG_HOME=${PWD}/demo XDG_DATA_HOME=${PWD}/deps nvim --noplugin -u demo/init.vim -c "set rtp+=${PWD}"

lint:
	luacheck lua
