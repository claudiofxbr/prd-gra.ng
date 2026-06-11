import Link from 'next/link'

export default function Home() {
  return (
    <main className="min-h-screen flex flex-col">
      {/* Hero */}
      <section
        className="flex-1 flex flex-col items-center justify-center text-center px-4 py-20"
        style={{
          background: 'linear-gradient(to bottom, var(--surface-raised), var(--surface-base))',
        }}
      >
        <h1
          className="text-4xl md:text-5xl font-bold mb-4"
          style={{ color: 'var(--content-primary)' }}
        >
          PRD-GRA
        </h1>
        <p
          className="text-xl mb-2 max-w-2xl"
          style={{ color: 'var(--content-secondary)' }}
        >
          Gerador de Documentos de Requisitos de Software
        </p>
        <p
          className="mb-10 max-w-xl"
          style={{ color: 'var(--content-muted)' }}
        >
          Crie, edite e compartilhe PRDs profissionais com stack tecnológica definida,
          objetivos claros e controle de status.
        </p>
        <div className="flex flex-col sm:flex-row gap-4">
          <Link href="/prd" className="btn-primary text-center px-8 py-3 text-base">
            Meus PRDs
          </Link>
          <Link href="/prd/new" className="btn-secondary text-center px-8 py-3 text-base">
            Criar Novo PRD
          </Link>
        </div>
      </section>

      {/* Features */}
      <section className="py-16 px-4 max-w-5xl mx-auto w-full">
        <h2
          className="text-2xl font-bold text-center mb-10"
          style={{ color: 'var(--content-primary)' }}
        >
          Tudo que você precisa para documentar seus projetos
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {features.map((f) => (
            <div key={f.title} className="card">
              <div className="text-3xl mb-3">{f.icon}</div>
              <h3
                className="font-semibold text-lg mb-2"
                style={{ color: 'var(--content-primary)' }}
              >
                {f.title}
              </h3>
              <p
                className="text-sm"
                style={{ color: 'var(--content-muted)' }}
              >
                {f.description}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section
        className="py-14 px-4 text-center"
        style={{ backgroundColor: 'var(--accent)', color: '#fff' }}
      >
        <h2 className="text-2xl font-bold mb-4">Pronto para começar?</h2>
        <p className="mb-6 opacity-90">
          Crie sua conta gratuitamente e comece a documentar.
        </p>
        <Link
          href="/register"
          className="font-semibold px-8 py-3 rounded-lg transition-colors inline-block"
          style={{
            backgroundColor: 'var(--surface-base)',
            color: 'var(--accent)',
          }}
          onMouseOver={(e) => {
            (e.currentTarget as HTMLAnchorElement).style.backgroundColor = 'var(--surface-raised)'
          }}
          onMouseOut={(e) => {
            (e.currentTarget as HTMLAnchorElement).style.backgroundColor = 'var(--surface-base)'
          }}
        >
          Criar Conta
        </Link>
      </section>

      <footer
        className="text-center py-6 text-sm"
        style={{ color: 'var(--content-muted)' }}
      >
        © 2026 PRD-GRA · Todos os direitos reservados
      </footer>
    </main>
  )
}

const features = [
  {
    icon: '📄',
    title: 'PRDs Estruturados',
    description: 'Defina título, descrição, stack tecnológica e objetivos de forma organizada.',
  },
  {
    icon: '🔄',
    title: 'Controle de Status',
    description: 'Acompanhe seus documentos em DRAFT, REVIEW ou APPROVED.',
  },
  {
    icon: '🔒',
    title: 'Seguro e Privado',
    description: 'Cada usuário acessa apenas seus próprios documentos. Dados criptografados.',
  },
]
