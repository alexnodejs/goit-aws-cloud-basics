# Провайдер AWS. Використовується профіль goit-aws-mds (змінна aws_profile)
# та регіон eu-central-1 (змінна aws_region).
# default_tags автоматично додаються до всіх ресурсів — так легко знайти
# все, що створено цим проєктом, у консолі AWS.
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region

  default_tags {
    tags = {
      Project   = "goit-aws-cloud-basics"
      ManagedBy = "terraform"
    }
  }
}
