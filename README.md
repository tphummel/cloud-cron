# Cloud Cron

- Use Terraform Cloud, Github (+Actions), and AWS to quickly create an inexpensive, low-maintenance scheduled job.
- Update your job with a painless release workflow.

Ship an update to your cron job in three easy steps:

1. push a branch with your code changes, a bump to the package.json version, and a reference to the new version in your terraform
1. merge your PR
1. apply the changes in terraform cloud

Other features:

- Job comes built in with permissions to write to data/ directory in the associated bucket

# setup

## accounts required

- github.com (free)
- terraform cloud (free)
- aws (free tier eligible)

## repo setup

- clone this repo
- `rm -rf .git`
- `git init`
- github.com
  - create a new empty repo
- `git remote add origin <remote-url>`

## configuration

- AWS
  - *out of band*, create an AWS user `terraform-cloud` and access key, with attached managed policies:
    - AWSLambdaFullAccess
    - IAMFullAccess
    - AmazonS3FullAccess
    - CloudWatchFullAccess

- Terraform Cloud
  - create an organization
  - create a workspace in the organization
  - Add environment variables to your workspace, for the `terraform-cloud` access keys you created above:
    - `AWS_ACCESS_KEY_ID`
    - `AWS_SECRET_ACCESS_KEY`
  - update the terraform cloud remote backend details in `main.tf`

- After the first `terraform apply`:
  - create github repo secrets (settings > secrets), using the values in terraform cloud (view in state):
    - created for the `<project-name>_CI` user
      - `AWS_ACCESS_KEY_ID`
      - `AWS_SECRET_ACCESS_KEY`
    - `bucket_name`



# release workflow

## code changes
1. make changes to lambda node.js code or dependencies
1. make changes to terraform config

## local checks

### format code

```
npm run fix
terraform fmt
```

### test app code

```
npm test

```

### validate terraform config

```
terraform validate
```

### set new version to deploy

```
npm version --no-git-tag-version patch
```

reference the new version in main.tf > `aws_lambda_function` s3 path setting

then commit the package and package-lock.json changes along with a reference to the new version in terraform.

push the branch changes to github

## remote review
1. open a new pull request
1. review github actions check status
1. review terraform cloud check status

## merge and deploy
1. on merge, the new tag will be created for the version specified in package.json
1. view the results of the github actions run for the master merge commit
1. review the terraform plan in terraform cloud
1. apply the plan in terraform cloud
