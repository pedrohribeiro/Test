# Configuração da Organização Salesforce

## Credenciais de Acesso

- **Login:** pedrohenrique401472@agentforce.com
- **Senha:** EverymindTeste123
- **URL de Login:** [login.salesforce.com](https://login.salesforce.com)

## Configurações do Objeto Account

### Campos Criados

1. **External ID**
   - Tipo: Texto
   - Descrição: Campo para armazenar um identificador externo único para a conta.

2. **CNPJ**
   - Tipo: Texto
   - Descrição: Campo para armazenar o CNPJ da conta.

### Regra de Validação

- **Nome da Regra:** CNPJ_Format_Validator
- **Descrição:** Garante que o CNPJ inserido no campo CNPJ esteja em um formato válido.
