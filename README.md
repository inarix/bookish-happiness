# bookish-happiness
Auto generated name for ArgoCD model deployment Github Action

## Outputs

### `modelInstanceId`

Id of the registered model that has been deployed to ArgoCD. This is required by ``potential-fortnight`` Github Action to run loki integration tests.

## Example usage
```yaml
- name: coverage
  id: deploy_model
  uses: inarix/bookish-happiness@v1
- name: comment PR
  uses: unsplash/comment-on-pr@master
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    DEPLOYED_MODEL_ID: ${{ steps.deploy_model.outputs.modelInstanceId }}
  with:
    msg: 'Deployed exported model (id: $DEPLOYED_MODEL_ID)'
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