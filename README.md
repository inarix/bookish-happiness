# bookish-happiness
Auto generated name for ArgoCD model deployment Github Action

## Outputs

### `modelName`

Name of the model that has been deployed to ArgoCD. This can be used for github comment-on-pr step.

### `modelVersion`

Version of the model that has been deployed to ArgoCD. This can be used for github comment-on-pr step.

## Example usage
```yaml
- name: coverage
  id: deploy_model
  uses: inarix/bookish-happiness@v1
- name: comment PR
  uses: unsplash/comment-on-pr@master
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    msg: 'Deployed model'
    check_for_duplicate_msg: false
```

## How to create Github action

First create a folder **.github/workflows** then create a new YAML file called with the name of the Job you want to create.

For example you can create ```.github/workflows/main.yaml```
```yaml
name: Deploy model on ArgoCD
on: pull_request
jobs:
  deploy-model:
    name: ArgoCD model deployment 
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy Model
        id: deploy_model`
        uses: inarix/bookish-happiness@v1
      - name: comment PR
        uses: unsplash/comment-on-pr@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          msg: 'Deployed Model'
          check_for_duplicate_msg: true
```

This will create a Github Action on each update (push, rebase ...) in a pull request.

NB: You need to always add ```- uses: actions/checkout@v2``` for the github action to fetch your code !