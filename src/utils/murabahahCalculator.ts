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
  if (!Number.isFinite(principal) || principal <= 0 || !Number.isSafeInteger(principal)) throw new Error('Nominal pembiayaan harus lebih besar dari 0.')
  if (!Number.isInteger(tenorMonths) || tenorMonths <= 0) throw new Error('Tenor pembiayaan tidak valid.')
  if (!Number.isFinite(marginRate) || marginRate < 0) throw new Error('Margin produk tidak valid.')
  if (input.adminFeeValue != null && (!Number.isFinite(input.adminFeeValue) || input.adminFeeValue < 0)) throw new Error('Biaya administrasi tidak boleh negatif.')
  if (input.minimumPrincipal != null && principal < input.minimumPrincipal) throw new Error('Nominal di bawah batas minimum produk.')
  if (input.maximumPrincipal != null && principal > input.maximumPrincipal) throw new Error('Nominal di atas batas maksimum produk.')
  if (input.tenorOptions?.length && !input.tenorOptions.includes(tenorMonths)) throw new Error('Tenor tidak tersedia untuk produk.')

  const principalCents = toScaledInteger(principal, 2)
  const rateScale = 100_000_000n
  const rate = toScaledInteger(marginRate, 8)
  const marginCents = principalCents * rate / (100n * rateScale)
  const sellingCents = principalCents + marginCents
  const principalBase = principalCents / BigInt(tenorMonths)
  const marginBase = marginCents / BigInt(tenorMonths)
  const regularInstallment = principalBase + marginBase
  const lastInstallment = sellingCents - (regularInstallment * BigInt(tenorMonths - 1))
  const schedule = Array.from({ length: tenorMonths }, (_, index) => {
    const installmentNo = index + 1
    const last = installmentNo === tenorMonths
    return {
      installmentNo,
      principalAmount: fromCents(last ? principalCents - principalBase * BigInt(tenorMonths - 1) : principalBase),
      marginAmount: fromCents(last ? marginCents - marginBase * BigInt(tenorMonths - 1) : marginBase),
      totalAmount: fromCents(last ? lastInstallment : regularInstallment),
    }
  })
  const scheduleTotal = schedule.reduce((sum, row) => sum + toScaledInteger(row.totalAmount, 2), 0n)
  if (scheduleTotal !== sellingCents) throw new Error('Total jadwal angsuran tidak sama dengan harga jual.')
  const adminFee = input.adminFeeType === 'PERCENTAGE'
    ? fromCents(principalCents * toScaledInteger(input.adminFeeValue ?? 0, 8) / (100n * rateScale))
    : input.adminFeeType === 'FIXED' ? fromCents(toScaledInteger(input.adminFeeValue ?? 0, 2)) : 0
  return { principal, marginRate, marginAmount: fromCents(marginCents), sellingPrice: fromCents(sellingCents), monthlyInstallment: fromCents(regularInstallment), adminFee, totalInitialCost: principal + adminFee, schedule }
}

function toScaledInteger(value: number, decimals: number): bigint {
  const [whole, fraction = ''] = String(value).split('.')
  return BigInt(`${whole}${fraction.padEnd(decimals, '0').slice(0, decimals)}`)
}

function fromCents(value: bigint): number {
  return Number(value) / 100
}
