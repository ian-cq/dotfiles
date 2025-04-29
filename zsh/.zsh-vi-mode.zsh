function fzf_cd_widget() {
  zle fzf-cd-widget
}
zle -N fzf_cd_widget

function backward_delete_word() {
  zle backward-delete-word
}
zle -N backward_delete_word

function zvm_config() {
  ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
  ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
  ZVM_INIT_MODE=sourcing

  # zvm_define_widget backward_delete_word
  # zvm_define_widget fzf_cd_widget
  # zvm_bindkey viins '\e\x7f' backward_delete_word
  # zvm_bindkey vicmd '^F' fzf_cd_widget
}

ZVM_CONFIG=zvm_config

