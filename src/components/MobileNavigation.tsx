import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'

export function MobileNavigation({ sources, selected, onSelect, staff }: {
  sources: Array<{ label: string }>; selected: number; onSelect: (index: number) => void; staff: boolean
}) {
  const [expanded, setExpanded] = useState(false)
  const [, setParams] = useSearchParams()
  const primary = staff ? [1, 0, 3] : [2, 4, 0]
  return <nav aria-label="Menu layanan" className="mobile-navigation lg:hidden">
    <button onClick={() => { setParams({ view: 'home' }); setExpanded(false) }} aria-current={selected === -1 ? 'page' : undefined} className="w-full border-b text-sm font-semibold text-green-800">Beranda</button>
    {expanded && <div className="grid grid-cols-2 gap-2 border-b p-3">{sources.map((source, index) => <button key={source.label} aria-current={selected === index ? 'page' : undefined} onClick={() => { onSelect(index); setExpanded(false) }} className="rounded-lg border px-3 text-left text-sm">{source.label}</button>)}</div>}
    <div className="grid grid-cols-4 gap-1 p-2">{primary.map((index) => <button key={index} aria-current={selected === index ? 'page' : undefined} onClick={() => { onSelect(index); setExpanded(false) }} className={`rounded-lg px-1 text-xs font-semibold ${selected === index ? 'bg-green-100 text-green-900' : 'text-slate-700'}`}>{sources[index]?.label}</button>)}<button aria-expanded={expanded} onClick={() => setExpanded(!expanded)} className="rounded-lg px-1 text-xs font-semibold">{expanded ? 'Tutup menu' : 'Lainnya'}</button></div>
  </nav>
}
