import { describe, expect, it } from 'vitest'
import { calculateMurabahah } from './murabahahCalculator'

describe('calculateMurabahah', () => {
  it('calculates Rp50m, 12 months, 12% flat margin', () => {
    const result = calculateMurabahah({ principal: 50_000_000, tenorMonths: 12, marginRate: 12, adminFeeType: 'PERCENTAGE', adminFeeValue: 1 })
    expect(result.marginAmount).toBe(6_000_000)
    expect(result.sellingPrice).toBe(56_000_000)
    expect(result.monthlyInstallment).toBe(4_666_666)
    expect(result.adminFee).toBe(500_000)
    expect(result.schedule).toHaveLength(12)
    expect(result.schedule.reduce((sum, row) => sum + row.totalAmount, 0)).toBe(56_000_000)
  })

  it('puts rounding remainder in the final installment', () => {
    const result = calculateMurabahah({ principal: 100, tenorMonths: 3, marginRate: 10 })
    expect(result.schedule.map((row) => row.totalAmount)).toEqual([36, 36, 38])
    expect(result.schedule.reduce((sum, row) => sum + row.totalAmount, 0)).toBe(result.sellingPrice)
  })

  it('rejects amount and tenor outside product rules', () => {
    expect(() => calculateMurabahah({ principal: 4, tenorMonths: 12, marginRate: 10, minimumPrincipal: 5 })).toThrow('minimum')
    expect(() => calculateMurabahah({ principal: 5, tenorMonths: 24, marginRate: 10, tenorOptions: [6, 12] })).toThrow('Tenor')
  })
})
