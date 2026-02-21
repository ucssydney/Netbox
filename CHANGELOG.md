name: Script Validation

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  shellcheck:
    name: ShellCheck Validation
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      
    - name: Run ShellCheck
      uses: ludeeus/action-shellcheck@master
      with:
        scandir: '.'
        severity: warning
        
  syntax-check:
    name: Bash Syntax Check
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      
    - name: Verify script syntax
      run: |
        bash -n deploy_netbox.sh
        bash -n setup_git_repo.sh
        
  markdown-lint:
    name: Markdown Lint
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      
    - name: Lint markdown files
      uses: articulate/actions-markdownlint@v1
      with:
        config: .markdownlint.json
        files: '*.md'
        ignore: node_modules
        version: 0.31.1
      continue-on-error: true
