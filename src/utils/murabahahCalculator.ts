export type FeeType = 'NONE' | 'FIXED' | 'PERCENTAGE'

export type MurabahahCalculatorInput = {
  principal: number
  tenorMonths: number
  marginRate: number
  minimumPrincipal?: number
  maximumPrincipal?: number | null
  tenorOptions?: number[]
  adminFeeType?: FeeType
  adminFeeValue?: number
}

export type MurabahahInstallment = {
  installmentNo: number
  principalAmount: number
  marginAmount: number
  totalAmount: number
}

export type MurabahahSimulation = {
  principal: number
  marginRate: number
  marginAmount: number
  sellingPrice: number
  monthlyInstallment: number
  adminFee: number
  totalInitialCost: number
  schedule: MurabahahInstallment[]
}

export function calculateMurabahah(input: MurabahahCalculatorInput): MurabahahSimulation {
  const { principal, tenorMonths, marginRate } = input
  if (!Number.isFinite(principal) || principal <= 0) throw new Error('Nominal pembiayaan harus lebih besar dari 0.')
  if (!Number.isInteger(tenorMonths) || tenorMonths <= 0) throw new Error('Tenor pembiayaan tidak valid.')
  if (!Number.isFinite(marginRate) || marginRate < 0) throw new Error('Margin produk tidak valid.')
  if (input.minimumPrincipal != null && principal < input.minimumPrincipal) throw new Error('Nominal di bawah batas minimum produk.')
  if (input.maximumPrincipal != null && principal > input.maximumPrincipal) throw new Error('Nominal di atas batas maksimum produk.')
  if (input.tenorOptions?.length && !input.tenorOptions.includes(tenorMonths)) throw new Error('Tenor tidak tersedia untuk produk.')

  const marginAmount = Math.floor(principal * marginRate / 100)
  const sellingPrice = principal + marginAmount
  const principalBase = Math.floor(principal / tenorMonths)
  const marginBase = Math.floor(marginAmount / tenorMonths)
  const regularInstallment = principalBase + marginBase
  const lastInstallment = sellingPrice - (regularInstallment * (tenorMonths - 1))
  const schedule = Array.from({ length: tenorMonths }, (_, index) => {
    const installmentNo = index + 1
    const last = installmentNo === tenorMonths
    return {
      installmentNo,
      principalAmount: last ? principal - (principalBase * (tenorMonths - 1)) : principalBase,
      marginAmount: last ? marginAmount - (marginBase * (tenorMonths - 1)) : marginBase,
      totalAmount: last ? lastInstallment : regularInstallment,
    }
  })
  const adminFee = input.adminFeeType === 'PERCENTAGE'
    ? Math.floor(principal * (input.adminFeeValue ?? 0) / 100)
    : input.adminFeeType === 'FIXED' ? Math.max(0, Math.floor(input.adminFeeValue ?? 0)) : 0
  return { principal, marginRate, marginAmount, sellingPrice, monthlyInstallment: regularInstallment, adminFee, totalInitialCost: principal + adminFee, schedule }
}
