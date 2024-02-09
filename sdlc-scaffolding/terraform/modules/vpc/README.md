# Documentação da Arquitetura e Boas Práticas para Configuração Terraform AWS VPC

Esta documentação detalha a configuração de uma Virtual Private Cloud (VPC) na AWS utilizando o Terraform. A arquitetura proposta visa fornecer uma base segura, escalável e altamente disponível para implantação de recursos AWS, focando nas melhores práticas de segurança e gerenciamento de rede.

A sub-rede escolhida é baseada no IPAM que faz o gerenciamento dos Pools de IP disponiveis para evitar overlapping.
As redes publica são implantada com mascara de rede /22 e as redes privadas com mascara /20


# Visão Geral da Arquitetura

A configuração cria uma VPC personalizada com sub-redes públicas e privadas distribuídas entre zonas de disponibilidade, um gateway de internet, gateways NAT para acesso à internet a partir das sub-redes privadas, e configuração DHCP personalizada. Também são configurados endpoints VPC para serviços AWS, permitindo comunicação segura sem necessitar de tráfego pela internet.

# Recursos Criados

aws_vpc (main): Define a VPC principal com suporte a DNS e hostnames DNS.
aws_vpc_dhcp_options (dhcp_options): Configura as opções DHCP para domínio e servidores DNS.
aws_vpc_dhcp_options_association (dns_resolver): Associa as opções DHCP configuradas com a VPC.
aws_subnet (public_subnets & private_subnets): Cria sub-redes públicas e privadas em múltiplas zonas de disponibilidade.
aws_internet_gateway (igw): Provê um gateway de internet para a VPC.
aws_eip (nat_eip): Aloca um endereço IP elástico para o gateway NAT.
aws_nat_gateway (nat): Configura o gateway NAT usando o EIP, permitindo acesso à internet a partir das sub-redes privadas.
aws_route_table (primary_rtb & secondary_rtb): Define tabelas de roteamento para as sub-redes, incluindo rotas para o gateway de internet e o NAT gateway.
aws_route_table_association (public_subnet_asso & private_subnet_asso): Associa as sub-redes às tabelas de roteamento apropriadas.
aws_vpc_endpoint (vpc_gateway_endpoints & vpc_interface_endpoints): Configura endpoints de gateway e de interface para serviços AWS específicos.

# Boas Práticas e Segurança

# Estrutura de Rede
Separação de Tráfego: Sub-redes públicas e privadas garantem a separação do tráfego, onde somente recursos que necessitam de acesso direto à internet são colocados nas sub-redes públicas.
Minimização da Superfície de Ataque: Utilizar gateways NAT e endpoints VPC para serviços AWS reduz o tráfego exposto à internet, minimizando a superfície de ataque.

# Alta Disponibilidade

Zonas de Disponibilidade: Distribuir sub-redes por múltiplas zonas de disponibilidade aumenta a resiliência e disponibilidade dos serviços, protegendo contra falhas em uma única zona.

# Gerenciamento de DNS e DHCP

Opções DHCP: Utilizado DHCP personalizadas para melhorar a resolução de nomes dentro da VPC para serviços AWS, facilitando a comunicação interna e a administração.

Acesso à Internet
Gateways NAT: Utilização de gateways NAT para acesso à internet a partir de sub-redes privadas permite que instâncias nessas sub-redes acessem recursos externos de forma segura, sem expô-las diretamente à internet.

Segurança
Endpoints VPC: Utilizado endpoints VPC para acesso direto a serviços AWS sem passar pela internet e reforçar a segurança e reduz a latência.

Segurança de Sub-redes: As tags específicas de Kubernetes nas sub-redes privadas ("kubernetes.io/role/internal-elb" = 1) indicam uma configuração para integração com um ambiente de Kubernetes, otimizando a segurança e o roteamento para carga de trabalho em containers.

# Gerenciamento e Monitoramento

Tags: Utilizar tags de forma consistente para todos os recursos permite um gerenciamento eficaz, facilitando a identificação, organização e monitoramento de custos.

# Conclusão
A configuração proposta utiliza o Terraform para estabelecer uma arquitetura de rede na AWS que segue as melhores práticas de segurança, escalabilidade e alta disponibilidade. A estrutura cuidadosamente planejada suporta uma ampla gama de aplicações e serviços, proporcionando uma base sólida para a implantação de infraestrutura na nuvem.