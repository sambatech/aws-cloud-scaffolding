De acordo com a própria documentação do Apache Skywalking o melhor storage type para este produto é o BanyanDB que ainda está em Alpha.

O segundo storage type é o ElasticSearch/OpenSearch, porém no terraform, estes módulos ainda não suportam o dualstack ipv4/ipv6.

Por fim, vamos usar o PostgreSQL até ser possível usar o ElasticSearch/OpenSearch gerenciado da AWS.