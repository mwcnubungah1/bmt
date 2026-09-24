import { useEffect, useState } from 'react'
import { fetchDashboardRows, PAGE_SIZE, type DashboardRow, type DashboardSource } from '../lib/dashboard-data'
import { formatUserError } from '../lib/errors'

export function useDashboardRows(staff: boolean, source: DashboardSource, page: number, search = '', status = '') {
  const [revision, setRevision] = useState(0)
  const [state, setState] = useState({ rows: [] as DashboardRow[], loading: true, error: '', hasNextPage: false })
  useEffect(() => {
    let active = true
    // Reset the visible result whenever the requested server page changes.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setState({ rows: [], loading: true, error: '', hasNextPage: false })
    void fetchDashboardRows(staff, source, page, search, status).then((result) => {
      if (result.error) throw result.error
      if (active) setState({ rows: result.data.slice(0, PAGE_SIZE), hasNextPage: result.hasNextPage, loading: false, error: '' })
    }).catch((error: unknown) => {
      if (active) setState({ rows: [], hasNextPage: false, loading: false, error: formatUserError(error) })
    })
    return () => { active = false }
  }, [staff, source, page, revision, search, status])
  return { ...state, reload: () => setRevision((value) => value + 1) }
}
