#!/usr/bin/env python3
"""
Gera PDF de apresentacao da solucao proposta (V2)
Diagramas gerados com Mermaid via mmdc (npx @mermaid-js/mermaid-cli)
Formato: A4 Landscape (297mm x 210mm)
"""

from fpdf import FPDF
from fpdf.enums import XPos, YPos
import os

PAGE_W = 297
PAGE_H = 210
MARGIN = 12

C_AZUL_ESCURO = (0, 51, 102)
C_AZUL_MEDIO = (0, 102, 204)
C_AZUL_CLARO = (200, 225, 245)
C_BRANCO = (255, 255, 255)
C_PRETO = (30, 30, 30)
C_CINZA = (100, 100, 100)
C_CINZA_CLARO = (240, 240, 240)
C_VERDE = (0, 150, 80)
C_VERMELHO = (200, 50, 50)
C_LARANJA = (230, 140, 0)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


class Presentation(FPDF):
    def __init__(self):
        super().__init__(orientation='L', unit='mm', format='A4')
        self.set_auto_page_break(False)

    def header_block(self, title, subtitle=None):
        self.set_fill_color(*C_AZUL_ESCURO)
        self.rect(0, 0, PAGE_W, 15, 'F')
        self.set_text_color(*C_BRANCO)
        self.set_font('Helvetica', 'B', 11)
        self.set_xy(MARGIN, 3)
        self.cell(0, 9, title, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        if subtitle:
            self.set_font('Helvetica', '', 8)
            self.set_xy(PAGE_W - MARGIN - 80, 3)
            self.cell(80, 9, subtitle, align='R', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_fill_color(*C_AZUL_MEDIO)
        self.rect(0, 15, PAGE_W, 1, 'F')

    def footer_block(self, page_num, total):
        self.set_fill_color(*C_CINZA_CLARO)
        self.rect(0, PAGE_H - 7, PAGE_W, 7, 'F')
        self.set_text_color(*C_CINZA)
        self.set_font('Helvetica', 'I', 6)
        self.set_xy(MARGIN, PAGE_H - 5.5)
        self.cell(0, 4, f"Proposta de Melhoria - Arquitetura V2  |  Slide {page_num}/{total}", align='L')

    def add_page_slide(self, title, subtitle=None):
        self.add_page()
        self.header_block(title, subtitle)
        self.footer_block(self.page_no(), self.pages_count)

    def card(self, x, y, w, h, color=C_BRANCO, border_color=C_AZUL_MEDIO):
        self.set_fill_color(*color)
        self.set_draw_color(*border_color)
        self.set_line_width(0.3)
        self.rect(x, y, w, h, 'DF')

    def bullet(self, x, y, text, size=8):
        self.set_text_color(*C_PRETO)
        self.set_font('Helvetica', '', size)
        self.set_fill_color(*C_AZUL_MEDIO)
        self.ellipse(x - 0.5, y + 1.2, 1.4, 1.4, 'F')
        self.set_xy(x + 2, y)
        self.multi_cell(PAGE_W - MARGIN - x - 5, 4.5, text)

    def section_title(self, x, y, text, size=10):
        self.set_fill_color(*C_AZUL_MEDIO)
        self.rect(x, y, 2.5, 5, 'F')
        self.set_text_color(*C_AZUL_ESCURO)
        self.set_font('Helvetica', 'B', size)
        self.set_xy(x + 5, y - 0.5)
        self.cell(0, 6, text)

    def table_row(self, x, y, cols, widths, header=False, colors=None):
        h = 6 if header else 5
        if colors is None:
            colors = [C_BRANCO] * len(cols)
        for i, (col, w) in enumerate(zip(cols, widths)):
            cx = x + sum(widths[:i])
            if header:
                self.set_fill_color(*C_AZUL_ESCURO)
                self.set_text_color(*C_BRANCO)
                self.set_font('Helvetica', 'B', 6.5)
            else:
                self.set_fill_color(*colors[i])
                self.set_text_color(*C_PRETO)
                self.set_font('Helvetica', '', 6.5)
            self.rect(cx, y, w, h, 'F')
            self.set_xy(cx + 0.5, y + 0.3)
            self.cell(w - 1, h - 0.5, str(col), align='C' if i > 0 else 'L')
        self.set_draw_color(*C_CINZA_CLARO)
        self.set_line_width(0.15)
        self.rect(x, y, sum(widths), h, 'D')


def generate_presentation():
    pdf = Presentation()
    pdf.set_margin(MARGIN)

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 1 - Titulo / Capa
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page()
    pdf.set_fill_color(*C_AZUL_ESCURO)
    pdf.rect(0, 0, PAGE_W, PAGE_H, 'F')
    pdf.set_fill_color(*C_AZUL_MEDIO)
    pdf.rect(0, 55, PAGE_W, 1.5, 'F')
    pdf.rect(0, 155, PAGE_W, 1.5, 'F')
    pdf.set_text_color(*C_BRANCO)
    pdf.set_font('Helvetica', 'B', 24)
    pdf.set_xy(0, 68)
    pdf.cell(PAGE_W, 12, 'Sistema de Armazenamento e Recuperacao', align='C')
    pdf.set_font('Helvetica', '', 13)
    pdf.set_xy(0, 84)
    pdf.cell(PAGE_W, 9, 'Proposta de Solucao V2 - Disaster Recovery, FinOps e Escalabilidade', align='C')
    pdf.set_fill_color(*C_AZUL_MEDIO)
    pdf.rect(PAGE_W / 2 - 35, 98, 70, 0.8, 'F')
    pdf.set_font('Helvetica', 'I', 10)
    pdf.set_text_color(*C_AZUL_CLARO)
    pdf.set_xy(0, 106)
    pdf.cell(PAGE_W, 7, 'Case Tecnico - Engenharia de Software Backend', align='C')
    pdf.set_xy(0, 116)
    pdf.cell(PAGE_W, 7, 'Itau Unibanco', align='C')

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 2 - Sumario da Apresentacao (bullets simples)
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('Sumario da Apresentacao', 'Agenda')
    x = MARGIN + 12
    y = 22

    pdf.section_title(x, y, 'Topicos Abordados na Solucao Proposta (V2)')
    y += 10

    summary_bullets = [
        "1. Arquitetura AWS (Diagrama Geral do README)",
        "2. Diagnostico e Arquitetura Atual (V1) - Stack e limitacoes",
        "3. Diagrama da Arquitetura V1 - Visao geral inicial em ECS Fargate",
        "4. Escolha NoSQL vs SQL - Justificativa tecnica para adocao do MongoDB",
        "5. MongoDB Atlas (Melhoria #1) - Cluster gerido, multi-AZ e DR",
        "6. Arquitetura Hexagonal (Melhoria #2) - Evolucao do DDD e isolamento",
        "7. Amazon EKS com Auto-Scaling (Melhoria #3) - Kubernetes, Karpenter e Spot",
        "8. SLOs Existentes e Propostas V2 - Analise do README, CloudWatch e metas",
        "9. FinOps e Calculo de Custos (Melhoria #4) - Custos V1 vs V2 e otimizacao",
        "10. AWS CodePipeline (Melhoria #5) - CI/CD nativo AWS e Blue/Green",
        "11. Disaster Recovery (Melhoria #6) - Estrategia cross-region e SLOs",
        "12. Diagrama da Arquitetura V2 - Fluxo completo em Amazon EKS",
        "13. Resumo e Trade-offs - Conclusao e analise de impacto",
    ]

    for i, b in enumerate(summary_bullets):
        pdf.set_fill_color(*C_AZUL_MEDIO)
        pdf.ellipse(x + 2, y + i * 11 + 1.2, 1.5, 1.5, 'F')
        pdf.set_text_color(*C_PRETO)
        pdf.set_font('Helvetica', '', 8)
        pdf.set_xy(x + 7, y + i * 11)
        pdf.cell(0, 4, b)

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 3 - Arquitetura AWS (Diagrama README.md)
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('Arquitetura AWS', 'Visao Geral do Sistema (README.md)')
    img_aws = os.path.join(SCRIPT_DIR, 'diagrama_aws_readme.png')
    if os.path.exists(img_aws):
        img_w = 265
        img_h = 210 * (850 / 1000)
        cx = (PAGE_W - img_w) / 2
        cy = (PAGE_H - img_h) / 2 + 5
        pdf.image(img_aws, x=cx, y=cy, w=img_w, h=img_h)
    else:
        pdf.set_text_color(*C_VERMELHO)
        pdf.set_font('Helvetica', 'I', 8)
        pdf.set_xy(MARGIN, 100)
        pdf.cell(0, 5, f'Diagrama AWS nao encontrado')

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 4 - Diagrama V1
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('Diagrama da Arquitetura Atual (V1)', 'ECS Fargate + MongoDB Auto-gerido')
    img_v1 = os.path.join(SCRIPT_DIR, 'diagrama_v1.png')
    if os.path.exists(img_v1):
        img_w = 210
        img_h = 210 * (700 / 900)
        cx = (PAGE_W - img_w) / 2
        cy = (PAGE_H - img_h) / 2 + 5
        pdf.image(img_v1, x=cx, y=cy, w=img_w, h=img_h)

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 5 - Arquitetura Atual (V1) - Diagnostico
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('Arquitetura Atual (V1) - Diagnostico', 'Visao Geral')
    x = MARGIN + 4
    y = 22

    pdf.section_title(x, y, 'Stack Atual')
    y += 8

    cards = [
        ("Compute", "ECS Fargate (2 tasks App + MongoDB) - 512 CPU / 1024 MB"),
        ("Database", "MongoDB 7.0 auto-gerido em ECS + EFS (Service Discovery)"),
        ("Arquitetura", "Domain Driven Design (DDD) - 4 modulos Maven acoplados"),
        ("CI/CD", "GitHub Actions - Deploy via script shell manual"),
        ("Observability", "CloudWatch + X-Ray - Logs e metricas basicas"),
        ("DR", "EFS como persistencia - Sem estrategia formal (RTO/RPO n/d)"),
    ]

    cw = 130
    ch = 14
    for i, (title, desc) in enumerate(cards):
        cx = x + (i % 2) * (cw + 8)
        cy = y + (i // 2) * (ch + 3)
        pdf.card(cx, cy, cw, ch, C_AZUL_CLARO)
        pdf.set_text_color(*C_AZUL_ESCURO)
        pdf.set_font('Helvetica', 'B', 7)
        pdf.set_xy(cx + 2, cy + 1)
        pdf.cell(cw - 4, 3.5, title)
        pdf.set_text_color(*C_PRETO)
        pdf.set_font('Helvetica', '', 6)
        pdf.set_xy(cx + 2, cy + 5)
        pdf.multi_cell(cw - 4, 3, desc)

    prob_y = y + 3 * (ch + 3) + 6
    pdf.section_title(x, prob_y, 'Problemas Identificados (Riscos e Limitacoes)')
    prob_y += 8

    problems = [
        "MongoDB auto-gerido: sem backup automatico, sem multi-AZ, RPO > 1h",
        "ECS Fargate: sem instancias Spot, custo fixo elevado sem auto-scaling eficiente",
        "Arquitetura DDD acoplada: regras de negocio misturadas com infraestrutura",
        "Pipeline CI/CD (GitHub Actions): sem blue/green nativo e rollback manual",
        "Ausencia de estrategia formal de Disaster Recovery (RTO/RPO nao definidos)",
        "FinOps nao implementado: falta de controle, alertas e otimizacao de custos",
    ]
    for i, p in enumerate(problems):
        pdf.bullet(x + 2, prob_y + i * 5, p, 7.5)

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 6 - Justificativa: NoSQL vs SQL
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('Escolha Tecnologica: NoSQL vs SQL', 'Justificativa de Banco de Dados')
    x = MARGIN + 4
    y = 22

    pdf.section_title(x, y, 'Por que MongoDB (NoSQL) ao inves de Bancos Relacionais (SQL)?')
    y += 9

    nosql_cards = [
        ("Flexibilidade de Schema e Documentos JSON",
         "Transacoes financeiras e eventos de contas possuem estruturas dinamicas e aninhadas. O formato de documento do MongoDB acomoda payloads complexos sem joins custosos ou migracoes de schema complexas."),
        ("Alta Escalabilidade Horizontal (Sharding)",
         "Sistemas bancarios de alta volumetria exigem escalabilidade horizontal nativa. O MongoDB Atlas permite sharding automatico e distribuicao de dados por chaves de particao, superando limites verticais de bancos relacionais tradicionais."),
        ("Performance em Escrita e Alta Disponibilidade",
         "Transacoes por segundo (TPS) elevadas beneficiam-se do motor WiredTiger e replica sets em 3 AZs. O modelo NoSQL reduz contention de locks comparado a transacoes relacionais pesadas em picos de requisicoes."),
        ("Alinhamento com Arquitetura Orientada a Eventos",
         "O consumo assincrono via SQS gera eventos mapeados diretamente para colecoes de documentos. A serializacao nativa JSON/BSON elimina camadas de ORM complexas, reduzindo latencia de persistencia.")
    ]

    for i, (title, desc) in enumerate(nosql_cards):
        cy = y + i * 36
        pdf.card(x, cy, PAGE_W - 2 * x - 8, 32, C_AZUL_CLARO)
        pdf.set_text_color(*C_AZUL_ESCURO)
        pdf.set_font('Helvetica', 'B', 8.5)
        pdf.set_xy(x + 4, cy + 2)
        pdf.cell(0, 5, title)
        pdf.set_text_color(*C_PRETO)
        pdf.set_font('Helvetica', '', 7.5)
        pdf.set_xy(x + 4, cy + 9)
        pdf.multi_cell(PAGE_W - 2 * x - 16, 4, desc)

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 7 - MongoDB Atlas
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('MongoDB Atlas - Cluster Gerido', 'Melhoria #1')
    x = MARGIN + 4
    y = 22

    pdf.section_title(x, y, 'Por que MongoDB Atlas?')
    y += 9

    pdf.card(x, y, PAGE_W - 2 * x, 28, C_AZUL_CLARO)
    pdf.set_text_color(*C_AZUL_ESCURO)
    pdf.set_font('Helvetica', 'B', 8)
    pdf.set_xy(x + 4, y + 2)
    pdf.cell(0, 4, 'Migracao de MongoDB auto-gerido (ECS + EFS) para MongoDB Atlas M10')
    pdf.set_text_color(*C_PRETO)
    pdf.set_font('Helvetica', '', 7)
    pdf.set_xy(x + 4, y + 8)
    pdf.multi_cell(PAGE_W - 2 * x - 8, 3.5,
        "O MongoDB Atlas elimina a complexidade operacional de gerir o proprio banco em ECS, oferecendo "
        "backup automatico, replicacao multi-AZ, escalabilidade elastica e snapshots para DR."
    )
    y += 33

    cols = ['Caracteristica', 'MongoDB Auto-gerido (V1)', 'MongoDB Atlas M10 (V2)']
    widths = [65, 95, 95]
    pdf.table_row(x, y, cols, widths, header=True)
    y += 6
    rows = [
        ('Backup', 'Manual (script shell)', 'Automatico (snapshots diarios)'),
        ('Multi-AZ', 'Nao', 'Sim (replicacao em 3 zonas)'),
        ('RPO', '> 1 hora', '< 5 minutos'),
        ('RTO', '> 30 minutos', '< 5 minutos (failover automatico)'),
        ('Escalabilidade', 'Vertical (aumentar task)', 'Horizontal (sharding nativo)'),
        ('Manutencao', 'Operacional (backup, restore)', 'Zero (gerido pela MongoDB)'),
        ('Custo', '~$2/mes (EFS + compute)', '~$60/mes (M10)'),
        ('Seguranca', 'Basica (senha + SG)', 'Encryption at rest, LDAP, VPC peering'),
    ]
    for i, row in enumerate(rows):
        bg = C_BRANCO if i % 2 == 0 else C_CINZA_CLARO
        pdf.table_row(x, y, row, widths, colors=[bg, bg, bg])
        y += 5

    y += 5
    pdf.section_title(x, y, 'Estrategia de Disaster Recovery com Atlas')
    y += 8
    dr_items = [
        "Snapshots automaticos diarios com retencao de 7 dias (gratuito no M10)",
        "Restore point-in-time (PIT) com janela de 24h para recuperacao granular",
        "Replicacao cross-region (sa-east-1 -> us-east-1) para DR ativo-passivo",
        "Failover automatico em < 2 minutos sem intervencao manual",
        "Encryption at rest + TLS 1.3 para conformidade LGPD",
    ]
    for item in dr_items:
        pdf.bullet(x + 3, y, item, 7)
        y += 5

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 8 - Arquitetura Hexagonal
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('Arquitetura Hexagonal (Ports & Adapters)', 'Melhoria #2')
    x = MARGIN + 4
    y = 22

    pdf.section_title(x, y, 'Evolucao do DDD para Hexagonal Architecture')
    y += 9

    pdf.card(x, y, 130, 48, C_CINZA_CLARO, (200, 200, 200))
    pdf.set_text_color(*C_VERMELHO)
    pdf.set_font('Helvetica', 'B', 8)
    pdf.set_xy(x + 4, y + 2)
    pdf.cell(0, 4, '[X] DDD Atual (V1) - Acoplamento')
    pdf.set_text_color(*C_PRETO)
    pdf.set_font('Helvetica', '', 7)
    pdf.set_xy(x + 4, y + 9)
    pdf.multi_cell(122, 3.5,
        "- transaction-api module depende de infra diretamente\n"
        "- Controllers chamam repositorios concretos\n"
        "- Servicos de dominio misturados com infra\n"
        "- Dificuldade para trocar de banco (MongoDB -> DynamoDB)\n"
        "- Testes de unidade precisam de mocks pesados"
    )

    pdf.card(x + 140, y, 130, 48, C_AZUL_CLARO)
    pdf.set_text_color(*C_VERDE)
    pdf.set_font('Helvetica', 'B', 8)
    pdf.set_xy(x + 144, y + 2)
    pdf.cell(0, 4, '[V] Hexagonal Architecture (V2) - Isolamento')
    pdf.set_text_color(*C_PRETO)
    pdf.set_font('Helvetica', '', 7)
    pdf.set_xy(x + 144, y + 9)
    pdf.multi_cell(122, 3.5,
        "- Core domain isolado (sem dependencias externas)\n"
        "- Inbound ports: interfaces de entrada (use cases)\n"
        "- Outbound ports: interfaces de saida (repositorios)\n"
        "- Adapters concretos na camada de infraestrutura\n"
        "- Swap de adapters sem impacto no core (ex: MongoDB -> DynamoDB)"
    )

    y += 56
    pdf.section_title(x, y, 'Estrutura de Modulos (V2)')
    y += 9
    modules = [
        ("transaction-domain (Core)", "Entidades, Value Objects, Ports, Domain Events", C_AZUL_ESCURO),
        ("transaction-application (Inbound)", "Use Cases, DTOs, Mappers, Inbound Ports", C_AZUL_MEDIO),
        ("transaction-infrastructure (Outbound)", "Adapters: MongoDB, SQS, S3, CloudWatch, Security", C_AZUL_CLARO),
        ("transaction-api (Delivery)", "Controllers REST, Exception Handlers, Config Spring Boot", C_BRANCO),
    ]
    for title, desc, bg in modules:
        border = C_AZUL_MEDIO if bg == C_BRANCO else bg
        pdf.card(x, y, PAGE_W - 2 * x - 8, 10, bg, border)
        pdf.set_text_color(*C_PRETO)
        pdf.set_font('Helvetica', 'B', 7)
        pdf.set_xy(x + 3, y + 0.5)
        pdf.cell(75, 4, title)
        pdf.set_font('Helvetica', '', 6.5)
        pdf.set_xy(x + 80, y + 0.5)
        pdf.cell(0, 4, desc)
        y += 11

    y += 2
    pdf.set_text_color(*C_AZUL_ESCURO)
    pdf.set_font('Helvetica', 'I', 7)
    pdf.set_xy(x + 3, y)
    pdf.cell(0, 4, "Beneficio: Testabilidade total - core domain testado sem infraestrutura")

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 9 - Amazon EKS
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('Amazon EKS com Auto-Scaling', 'Melhoria #3')
    x = MARGIN + 4
    y = 22

    pdf.section_title(x, y, 'Evolucao: ECS Fargate -> Amazon EKS com Karpenter + HPA')
    y += 9

    cols = ['Caracteristica', 'ECS Fargate (V1)', 'Amazon EKS (V2)']
    widths = [65, 95, 95]
    pdf.table_row(x, y, cols, widths, header=True)
    y += 6
    rows = [
        ('Orquestracao', 'AWS proprietaria', 'Kubernetes (CNCF)'),
        ('Auto-scaling', 'Service Auto Scaling', 'HPA + Karpenter + CA'),
        ('Instancias', 'Sem escolha (Fargate)', 'Spot, On-Demand, Reserved'),
        ('Custo compute', '~$5-8/mes (2 tasks)', '~$0-3/mes (Spot, 1 node t3.medium)'),
        ('Tempo de cold start', '~30s (Fargate)', '~10s (Karpenter provision)'),
        ('Portabilidade', 'Lock-in AWS', 'Multi-cloud (CNCF)'),
        ('Ecossistema', 'Limitado', 'Helm, Prometheus, Istio, ArgoCD'),
        ('Plano de controlo', 'Gratis (Fargate)', '$0.10/hora (~$73/mes)'),
    ]
    for i, row in enumerate(rows):
        bg = C_BRANCO if i % 2 == 0 else C_CINZA_CLARO
        pdf.table_row(x, y, row, widths, colors=[bg, bg, bg])
        y += 5

    y += 5
    pdf.section_title(x, y, 'Estrategia de Auto-Scaling')
    y += 8
    scaling_items = [
        ("HPA", "Escala pods por CPU (70%) e memoria (80%). Min 2 pods, max 10."),
        ("Karpenter", "Escala nos automaticamente. Nos Spot (70% mais baratos) com fallback On-Demand."),
        ("Cluster Autoscaler", "Aloca pods nao schedulados. Remove nos vazios para otimizar custo."),
        ("Pod Disruption Budgets", "Garante pelo menos 1 pod disponivel durante atualizacoes."),
    ]
    for title, desc in scaling_items:
        pdf.card(x, y, PAGE_W - 2 * x - 8, 14, C_AZUL_CLARO)
        pdf.set_text_color(*C_AZUL_ESCURO)
        pdf.set_font('Helvetica', 'B', 7.5)
        pdf.set_xy(x + 4, y + 1)
        pdf.cell(0, 4, title)
        pdf.set_text_color(*C_PRETO)
        pdf.set_font('Helvetica', '', 6.5)
        pdf.set_xy(x + 4, y + 6.5)
        pdf.multi_cell(PAGE_W - 2 * x - 16, 3, desc)
        y += 16

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 10 - SLOs Existentes (README) e Propostas V2
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('SLOs - Service Level Objectives', 'Analise README & Propostas V2')
    x = MARGIN + 4
    y = 22

    pdf.section_title(x, y, 'SLOs Existentes no README.md')
    y += 9

    cols_slo = ['SLO', 'Metrica', 'Objetivo Atual', 'Justificativa Operacional']
    widths_slo = [35, 60, 35, 143]
    pdf.table_row(x, y, cols_slo, widths_slo, header=True)
    y += 6

    existing_slos = [
        ('SLO-1: Latencia P95', 'transaction.authorization.latency.percentile', '<= 2s', 'Transacoes bancarias devem ser rapidas para nao bloquear o fluxo do cliente'),
        ('SLO-2: Taxa de Falhas', 'transaction.total.count (status=FAILED)', '< 1%', 'Sistema financeiro 24h precisa de alta confiabilidade nas transacoes'),
        ('SLO-3: DLQ Messages', 'ApproximateNumberOfMessagesVisible (DLQ)', '0 msg', 'Mensagens na DLQ indicam falhas assincronas que exigem intervencao'),
        ('SLO-4: ALB 5xx', 'HTTPCode_Target_5XX_Count', '0 erros', 'Erros de servidor impactam diretamente a disponibilidade da API REST'),
        ('SLO-5: SQS Failures', 'sqs.messages.failed.count', '< 0.1%', 'Falhas no consumo de SQS indicam problemas no processamento de contas'),
    ]
    for i, row in enumerate(existing_slos):
        bg = C_BRANCO if i % 2 == 0 else C_CINZA_CLARO
        pdf.table_row(x, y, row, widths_slo, colors=[bg, bg, bg, bg, bg])
        y += 5

    y += 6
    pdf.section_title(x, y, 'Propostas de Melhoria de SLOs para a Arquitetura V2')
    y += 8

    slo_proposals = [
        ("SLO-6: Latencia P99 (Proposto V2)", "Meta: <= 800ms (reducao de 60% vs V1). Garantido pelo Amazon EKS + Karpenter + MongoDB Atlas M10 com menor latencia de rede e IOPS garantidas."),
        ("SLO-7: Disponibilidade (Uptime 99.99%)", "Meta: 99.99% de uptime (maximo de 4.38 min de indisponibilidade/mes). Alcancado via multi-AZ no EKS e MongoDB Atlas com failover automatico em < 2 min."),
        ("SLO-8: RPO e RTO Automatizados", "Meta: RPO < 5 min e RTO < 30 min validados por testes automatizados mensais de restore e failover cross-region (sa-east-1 -> us-east-1).")
    ]

    for title, desc in slo_proposals:
        pdf.card(x, y, PAGE_W - 2 * x - 8, 13, C_AZUL_CLARO)
        pdf.set_text_color(*C_AZUL_ESCURO)
        pdf.set_font('Helvetica', 'B', 7.5)
        pdf.set_xy(x + 3, y + 1)
        pdf.cell(0, 4, title)
        pdf.set_text_color(*C_PRETO)
        pdf.set_font('Helvetica', '', 6.5)
        pdf.set_xy(x + 3, y + 6)
        pdf.multi_cell(PAGE_W - 2 * x - 16, 3, desc)
        y += 14.5

    y += 4
    pdf.section_title(x, y, 'Monitoramento e Dashboards (CloudWatch)')
    y += 7
    pdf.set_text_color(*C_AZUL_ESCURO)
    pdf.set_font('Helvetica', 'B', 7)
    pdf.set_xy(x, y)
    pdf.cell(0, 4, "Dashboard: transaction-api_overview (7 widgets criados via Terraform)")
    pdf.set_font('Helvetica', '', 6.5)
    pdf.set_text_color(*C_PRETO)
    pdf.set_xy(x, y + 4)
    pdf.multi_cell(PAGE_W - 2 * x, 3, 
        "Inclui ECS CPU/Memory, ALB Requests, Business Metrics (transacoes, latencia, saldo), SQS Queue, SLO Compliance, Alarms e Logs.\n"
        "Link: https://sa-east-1.console.aws.amazon.com/cloudwatch/home?region=sa-east-1#dashboards:name=transaction-api_overview"
    )

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 11 - FinOps
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('FinOps - Calculo de Custo Detalhado', 'Melhoria #4')
    x = MARGIN + 4
    y = 22

    pdf.section_title(x, y, 'Comparativo de Custos Mensais Estimados')
    y += 9

    cols = ['Componente', 'V1 (ECS Fargate)', 'V2 (EKS + Atlas)', 'Diferenca']
    widths = [55, 70, 70, 60]
    pdf.table_row(x, y, cols, widths, header=True)
    y += 6
    cost_rows = [
        ('Compute (App)', '$5.00 (Fargate)', '$1.50 (Spot t3.medium)', '-$3.50'),
        ('Compute (MongoDB)', '$3.00 (Fargate)', '$0.00 (Atlas inclui)', '-$3.00'),
        ('Database', '$2.00 (EFS 25GB)', '$60.00 (Atlas M10)', '+$58.00'),
        ('ALB', '$0.00 (Free Tier)', '$0.00 (Free Tier)', '$0.00'),
        ('SQS + DLQ', '$0.00 (1M gratis)', '$0.00 (1M gratis)', '$0.00'),
        ('CloudWatch', '$0.00 (10GB gratis)', '$0.00 (10GB gratis)', '$0.00'),
        ('Secrets Manager', '$0.40 (1 secret)', '$0.40 (1 secret)', '$0.00'),
        ('ECR', '$0.00 (500MB gratis)', '$0.00 (500MB gratis)', '$0.00'),
        ('EKS Control Plane', '$0.00', '$73.00 (730h)', '+$73.00'),
        ('X-Ray', '$0.00 (100K traces)', '$0.00 (100K traces)', '$0.00'),
        ('Pipeline (CI/CD)', '$0.00 (GitHub)', '$1.50 (CodePipeline)', '+$1.50'),
        ('', '', '', ''),
        ('TOTAL ESTIMADO', '~$10.40/mes', '~$136.40/mes', '+$126.00'),
    ]
    for i, row in enumerate(cost_rows):
        if row[0] == '':
            y += 0.5
            continue
        is_total = row[0] == 'TOTAL ESTIMADO'
        bg = C_BRANCO
        if i % 2 == 0 and not is_total:
            bg = C_CINZA_CLARO
        if is_total:
            bg = C_AZUL_ESCURO
        pdf.table_row(x, y, row, widths, header=is_total, colors=[bg, bg, bg, bg])
        y += 6 if not is_total else 7

    y += 5
    pdf.section_title(x, y, 'Estrategias de Otimizacao FinOps')
    y += 8
    finops_items = [
        "Savings Plans: compromisso de 1 ano reduz custo compute em ~30%",
        "Spot Instances: ate 70% mais barato que On-Demand para workloads stateless",
        "Auto-scaling baseado em demanda: elimina super-provisionamento",
        "S3 Lifecycle: STANDARD_IA (30d) -> GLACIER (60d) -> Expire (90d)",
        "MongoDB Atlas: M10 (2GB) dev, M20 (8GB) staging, M30 (16GB) producao",
        "CloudWatch: filtros de log para reduzir volume de dados ingeridos",
    ]
    for item in finops_items:
        pdf.bullet(x + 3, y, item, 7)
        y += 5

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 12 - AWS CodePipeline
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('AWS CodePipeline - CI/CD Nativo AWS', 'Melhoria #5')
    x = MARGIN + 4
    y = 22

    pdf.section_title(x, y, 'Transicao: GitHub Actions -> AWS CodePipeline')
    y += 9

    pipeline_steps = [
        ("1", "Source", "GitHub\nPush/PR", C_AZUL_ESCURO),
        ("2", "Build", "CodeBuild\nmvn test + package", C_AZUL_MEDIO),
        ("3", "Docker", "CodeBuild\ndocker build + push ECR", (50, 120, 180)),
        ("4", "Deploy", "CodeDeploy\nBlue/Green EKS", (30, 90, 150)),
        ("5", "Verify", "CodeBuild\nPost-deploy tests", (20, 70, 130)),
        ("6", "Rollback", "CloudWatch\nAutomatico se falha", C_VERMELHO),
    ]

    step_w = (PAGE_W - 2 * x - 48) / 6
    step_h = 28
    for i, (num, title, desc, bg) in enumerate(pipeline_steps):
        sx = x + i * (step_w + 6)
        pdf.card(sx, y, step_w, step_h, bg)
        pdf.set_text_color(*C_BRANCO)
        pdf.set_font('Helvetica', 'B', 12)
        pdf.set_xy(sx + 2, y + 1)
        pdf.cell(step_w - 4, 5, num, align='C')
        pdf.set_font('Helvetica', 'B', 6.5)
        pdf.set_xy(sx + 2, y + 7)
        pdf.cell(step_w - 4, 3, title, align='C')
        pdf.set_font('Helvetica', '', 6)
        pdf.set_xy(sx + 2, y + 12)
        pdf.multi_cell(step_w - 4, 3, desc, align='C')
        if i < len(pipeline_steps) - 1:
            pdf.set_text_color(*C_AZUL_MEDIO)
            pdf.set_font('Helvetica', 'B', 10)
            pdf.set_xy(sx + step_w + 0.5, y + 9)
            pdf.cell(5, 4, '>', align='C')

    y += 38
    pdf.section_title(x, y, 'GitHub Actions vs AWS CodePipeline')
    y += 9
    cols = ['Aspecto', 'GitHub Actions', 'AWS CodePipeline']
    widths = [55, 100, 100]
    pdf.table_row(x, y, cols, widths, header=True)
    y += 6
    comp_rows = [
        ('Integracao AWS', 'Indireta (OIDC)', 'Nativa (IAM + ECR + ECS + EKS)'),
        ('Blue/Green EKS', 'Script manual', 'CodeDeploy nativo'),
        ('Rollback', 'Custom script', 'Automatico via CloudWatch Alarms'),
        ('Custo', 'Gratis (publico)', '~$1.50/mes'),
        ('Auditoria', 'GitHub Audit Log', 'AWS CloudTrail'),
        ('Approval Gates', 'Environments', 'Manual approval stage nativo'),
        ('Tempo de deploy', '~8 min', '~5 min (integracao direta)'),
    ]
    for i, row in enumerate(comp_rows):
        bg = C_BRANCO if i % 2 == 0 else C_CINZA_CLARO
        pdf.table_row(x, y, row, widths, colors=[bg, bg, bg])
        y += 5

    y += 4
    pdf.set_text_color(*C_AZUL_ESCURO)
    pdf.set_font('Helvetica', 'I', 7)
    pdf.set_xy(x + 3, y)
    pdf.cell(0, 4, "Recomendacao: CodePipeline e ideal para times AWS-native")

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 13 - Disaster Recovery
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('Disaster Recovery - Estrategia Multi-AZ', 'Melhoria #6')
    x = MARGIN + 4
    y = 22

    pdf.section_title(x, y, 'Estrategia de Recuperacao de Desastres')
    y += 9

    dr_cards = [
        ("MongoDB Atlas - Replicacao Cross-Region",
         "Replica set em 3 AZs em sa-east-1\nCluster secundario em us-east-1 (DR)\nFailover automatico em < 2 min\nRPO: < 5 min | RTO: < 30 min"),
        ("EKS - GitOps com ArgoCD",
         "Cluster EKS multi-AZ (3 subnets)\nArgoCD GitOps: estado no Git\nRecuperacao automatica em DR\nRTO: < 15 min (aplicacao)"),
        ("Backup & Restore - Politica",
         "Snapshots Atlas: diarios, 7 dias\nPIT Restore: janela de 24h\nBackup configs EKS: etcd\nTestes de restore mensais"),
        ("Pipeline de DR - Automacao",
         "CloudWatch -> Lambda -> Restore\nTerraform provisionamento DR\nTestes de caos (Chaos Monkey)\nRunbook documentado no Git"),
    ]

    cw2 = (PAGE_W - 2 * x - 16) / 2
    ch2 = 40
    for i, (title, desc) in enumerate(dr_cards):
        cx = x + (i % 2) * (cw2 + 8)
        cy = y + (i // 2) * (ch2 + 6)
        bg = [(220, 238, 250), (210, 230, 245), (200, 225, 240), (215, 230, 248)][i]
        pdf.card(cx, cy, cw2, ch2, bg)
        pdf.set_text_color(*C_AZUL_ESCURO)
        pdf.set_font('Helvetica', 'B', 7.5)
        pdf.set_xy(cx + 4, cy + 2)
        pdf.cell(cw2 - 8, 4, title)
        pdf.set_text_color(*C_PRETO)
        pdf.set_font('Helvetica', '', 6.5)
        pdf.set_xy(cx + 4, cy + 9)
        pdf.multi_cell(cw2 - 8, 3.2, desc)

    y += 2 * ch2 + 12 + 5
    pdf.section_title(x, y, 'SLOs de Disaster Recovery')
    y += 8
    cols = ['SLO', 'Metrica', 'Objetivo', 'Como e Garantido']
    widths = [40, 55, 35, 125]
    pdf.table_row(x, y, cols, widths, header=True)
    y += 6
    slo_rows = [
        ('RPO', 'Recovery Point Objective', '< 5 min', 'Snapshot automatico Atlas a cada 5 min + WAL archiving'),
        ('RTO', 'Recovery Time Objective', '< 30 min', 'Failover automatico Atlas + ArgoCD + Terraform DR'),
        ('Disponibilidade', 'Uptime', '99.99%', 'Multi-AZ (3 zonas) + Health checks + Auto-healing'),
        ('Integridade', 'Consistencia dados', '100%', 'Transacoes ACID + Validacao pos-restore + Checksums'),
    ]
    for i, row in enumerate(slo_rows):
        bg = C_BRANCO if i % 2 == 0 else C_CINZA_CLARO
        pdf.table_row(x, y, row, widths, colors=[bg, bg, bg, bg])
        y += 5

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 14 - Diagrama da Arquitetura V2 (pagina dedicada)
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('Diagrama da Arquitetura Proposta (V2)', 'EKS + MongoDB Atlas + CodePipeline')
    img_v2 = os.path.join(SCRIPT_DIR, 'diagrama_v2.png')
    if os.path.exists(img_v2):
        img_w = 200
        img_h = 200 * (800 / 900)
        cx = (PAGE_W - img_w) / 2
        cy = (PAGE_H - img_h) / 2 + 5
        pdf.image(img_v2, x=cx, y=cy, w=img_w, h=img_h)
    else:
        pdf.set_text_color(*C_VERMELHO)
        pdf.set_font('Helvetica', 'I', 8)
        pdf.set_xy(MARGIN, 100)
        pdf.cell(0, 5, f'Diagrama nao encontrado: {img_v2}')

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 15 - Resumo e Trade-offs
    # ═══════════════════════════════════════════════════════════════
    pdf.add_page_slide('Resumo de Impacto e Trade-offs', 'Conclusao')
    x = MARGIN + 4
    y = 22

    pdf.section_title(x, y, 'Resumo das Melhorias Propostas')
    y += 9
    cols = ['Componente', 'V1 (Atual)', 'V2 (Proposta)', 'Impacto']
    widths = [48, 72, 72, 63]
    pdf.table_row(x, y, cols, widths, header=True)
    y += 6
    summary_rows = [
        ('Database', 'MongoDB auto-gerido', 'MongoDB Atlas M10', '[OK] DR, backup, multi-AZ'),
        ('Arquitetura', 'DDD', 'Hexagonal (Ports & Adapters)', '[OK] Testabilidade, isolamento'),
        ('Orquestracao', 'ECS Fargate', 'EKS + Karpenter + HPA', '[OK] Escalabilidade, Spot'),
        ('CI/CD', 'GitHub Actions', 'AWS CodePipeline', '[OK] Blue/Green, rollback'),
        ('DR', 'Inexistente', 'Multi-AZ + Cross-Region', '[OK] RPO < 5min, RTO < 30min'),
        ('FinOps', 'Nao implementado', 'Savings Plans + Spot + Lifecycle', '[OK] Otimizacao custos'),
    ]
    for i, row in enumerate(summary_rows):
        bg = C_BRANCO if i % 2 == 0 else C_CINZA_CLARO
        pdf.table_row(x, y, row, widths, colors=[bg, bg, bg, bg])
        y += 5

    y += 5
    pdf.section_title(x, y, 'Trade-offs e Riscos')
    y += 8
    tradeoffs = [
        ("Custo: V2 (~$136/mes) vs V1 (~$10/mes)",
         "Aumento justificado por resiliencia, DR, backup nativo e escalabilidade."),
        ("Complexidade Operacional: Kubernetes",
         "EKS requer conhecimento K8s. Karpenter, HPA e ArgoCD adicionam complexidade."),
        ("Lock-in MongoDB Atlas",
         "Atlas cria dependencia MongoDB. Alternativa futura: DynamoDB via Hexagonal."),
        ("Tempo de Migracao",
         "Migracao estimada em 4-6 semanas: Atlas, refactor, EKS, pipeline, testes DR."),
    ]
    for title, desc in tradeoffs:
        pdf.card(x, y, PAGE_W - 2 * x - 8, 18, C_CINZA_CLARO, (200, 200, 200))
        pdf.set_text_color(*C_LARANJA)
        pdf.set_font('Helvetica', 'B', 7.5)
        pdf.set_xy(x + 4, y + 1)
        pdf.cell(0, 4, title)
        pdf.set_text_color(*C_PRETO)
        pdf.set_font('Helvetica', '', 6.5)
        pdf.set_xy(x + 4, y + 7)
        pdf.multi_cell(PAGE_W - 2 * x - 16, 3, desc)
        y += 20

    y += 3
    pdf.section_title(x, y, 'Recomendacao Final')
    y += 8
    pdf.set_text_color(*C_AZUL_ESCURO)
    pdf.set_font('Helvetica', 'B', 8)
    pdf.set_xy(x + 3, y)
    pdf.multi_cell(PAGE_W - 2 * x - 6, 4.5,
        "A arquitetura V2 e recomendada para ambientes produtivos que exigem alta disponibilidade, "
        "recuperacao de desastres e escalabilidade. O custo adicional (~$126/mes) e compensado pela "
        "reducao de risco operacional, conformidade LGPD, e SLOs de RPO < 5 min e RTO < 30 min."
    )

    # Salvar PDF
    output_path = os.path.join(SCRIPT_DIR, 'apresentacao_solucao_v2.pdf')
    pdf.output(output_path)
    print(f"PDF gerado: {output_path} | Slides: {pdf.page_no()}")
    return output_path


if __name__ == '__main__':
    generate_presentation()