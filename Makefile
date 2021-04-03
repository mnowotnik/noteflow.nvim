
# TODO:
# - lint
# - format

test: deps
	nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/plenary/ {minimal_init = 'tests/minimal_init.vim'}"

deps:
	mkdir deps
	cd deps && git clone --depth 1 https://github.com/nvim-lua/plenary.nvim
	cd deps && git clone --depth 1 https://github.com/nvim-telescope/telescope.nvim
	cd deps && git clone --depth 1 https://github.com/nvim-lua/popup.nvim

ci-test: github-actions-setup.sh
	bash -c 'source github-actions-setup.sh nightly-x64 && export make test'

github-actions-setup.sh:
	curl -OL https://raw.githubusercontent.com/norcalli/bot-ci/master/scripts/github-actions-setup.sh

clean:
	rm -rf deps
