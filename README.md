# aws-cloud-scaffolding

# Documentação do Código Terraform
# Visão Geral

Este código Terraform é destinado a criar recursos na infraestrutura da Amazon Web Services (AWS) para provisionar e gerenciar um cluster do Amazon Elastic Kubernetes Service (EKS) e instâncias EC2 associadas a ele. O código também inclui a configuração de IAM Roles e políticas necessárias, além de outros recursos relacionados ao cluster EKS.

Recursos Criados
O código Terraform cria os seguintes recursos:

# AWS IAM Roles:

aws_iam_role.platform_cluster_role: 
Uma função IAM que permite que o cluster EKS assuma essa função.
aws_iam_role.platform_nodegroup_role: 
Uma função IAM que permite que os grupos de nodes assumam essa função.
aws_iam_role.platform_cluster_assume_role: 
Uma função IAM que permite que os pods assumam a função com base na autenticação do OpenID Connect (OIDC).

# AWS IAM Policies:

aws_iam_role_policy.platform_cluster_cloudwatch_policy: 
Uma política que permite ao cluster EKS enviar métricas para o CloudWatch.
aws_iam_role_policy_attachment.platform_cluster_policies_attachment: 
Anexa políticas adicionais ao cluster IAM Role.
aws_iam_role_policy_attachment.platform_nodegroup_policies_attachment: 
Anexa políticas adicionais ao grupo de nodes IAM Role.

# AWS EKS Cluster:

aws_eks_cluster.eks_cluster: 
Um cluster EKS com configurações específicas, incluindo VPC, subnets e políticas associadas.

# AWS IAM OpenID Connect Provider:

aws_iam_openid_connect_provider.oidc_provider:
Um provedor de autenticação OpenID Connect (OIDC) para autenticação baseada em OIDC no cluster EKS.

# AWS EKS Identity Provider Config:

aws_eks_identity_provider_config.eks_oidc_config: Configuração do provedor de identidade OIDC no cluster EKS.

# AWS Launch Templates:

aws_launch_template.reservada_launch_template: 
Um modelo de lançamento para instâncias EC2 reservadas.
aws_launch_template.spot_launch_template: 
Um modelo de lançamento para instâncias EC2 spot.

# AWS EKS Node Group:

aws_eks_node_group.reservada_node_group: 
Um grupo de nodes para instâncias EC2 reservadas.

# AWS Autoscaling Group:

aws_autoscaling_group.spot_autoscaling_group: 
Um grupo de escalabilidade automática para instâncias EC2 spot.

# Módulo de Addons:

Um módulo personalizado definido no diretório "addons" para configurar addons no cluster EKS. (Consulte a documentação separada do módulo de Addons para mais detalhes.)
Dependências
Este código Terraform possui algumas dependências entre os recursos, incluindo:

As políticas IAM devem ser anexadas às funções IAM antes da criação do cluster EKS para garantir que as permissões estejam configuradas corretamente.
Variáveis de Entrada
O código utiliza as seguintes variáveis de entrada, que devem ser definidas no arquivo de configuração do Terraform ou como argumentos na linha de comando:

var.eks_cluster_name: O nome desejado para o cluster EKS.
var.eks_subnets: Uma lista de objetos que especificam as subnets onde o cluster EKS será implantado.