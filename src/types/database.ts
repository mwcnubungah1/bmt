export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  bmt_db: {
    Tables: {
      customer_followups: {
        Row: { id: string; customer_id: string; owner_id: string; note: string; due_at: string; completed: boolean; created_at: string }
        Insert: { id?: string; customer_id: string; owner_id?: string; note: string; due_at: string; completed?: boolean; created_at?: string }
        Update: { completed?: boolean }
        Relationships: []
      }
      account_status_history: {
        Row: {
          changed_at: string
          changed_by: string | null
          financial_account_id: string
          id: string
          metadata: Json
          new_status: Database["bmt_db"]["Enums"]["account_status"]
          old_status: Database["bmt_db"]["Enums"]["account_status"] | null
          reason: string | null
        }
        Insert: {
          changed_at?: string
          changed_by?: string | null
          financial_account_id: string
          id?: string
          metadata?: Json
          new_status: Database["bmt_db"]["Enums"]["account_status"]
          old_status?: Database["bmt_db"]["Enums"]["account_status"] | null
          reason?: string | null
        }
        Update: {
          changed_at?: string
          changed_by?: string | null
          financial_account_id?: string
          id?: string
          metadata?: Json
          new_status?: Database["bmt_db"]["Enums"]["account_status"]
          old_status?: Database["bmt_db"]["Enums"]["account_status"] | null
          reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "account_status_history_financial_account_id_fkey"
            columns: ["financial_account_id"]
            isOneToOne: false
            referencedRelation: "financial_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      approval_requests: {
        Row: {
          approval_type: string
          branch_id: string
          created_at: string
          entity_id: string
          entity_type: string
          id: string
          maker_checker_required: boolean
          notes: string | null
          reason: string | null
          requested_at: string
          requested_by: string
          required_level: number
          required_role: string
          resolved_at: string | null
          resolved_by: string | null
          status: Database["bmt_db"]["Enums"]["approval_status"]
        }
        Insert: {
          approval_type: string
          branch_id: string
          created_at?: string
          entity_id: string
          entity_type: string
          id?: string
          maker_checker_required?: boolean
          notes?: string | null
          reason?: string | null
          requested_at?: string
          requested_by: string
          required_level?: number
          required_role: string
          resolved_at?: string | null
          resolved_by?: string | null
          status?: Database["bmt_db"]["Enums"]["approval_status"]
        }
        Update: {
          approval_type?: string
          branch_id?: string
          created_at?: string
          entity_id?: string
          entity_type?: string
          id?: string
          maker_checker_required?: boolean
          notes?: string | null
          reason?: string | null
          requested_at?: string
          requested_by?: string
          required_level?: number
          required_role?: string
          resolved_at?: string | null
          resolved_by?: string | null
          status?: Database["bmt_db"]["Enums"]["approval_status"]
        }
        Relationships: [
          {
            foreignKeyName: "approval_requests_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_approval_requests_requested_by"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_approval_requests_resolved_by"
            columns: ["resolved_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      approval_rules: {
        Row: {
          approval_level: number
          branch_id: string | null
          created_at: string
          effective_from: string
          effective_until: string | null
          id: string
          is_active: boolean
          maker_checker_required: boolean
          maximum_amount: number | null
          minimum_amount: number
          required_role: string
          transaction_type: string
          updated_at: string
        }
        Insert: {
          approval_level?: number
          branch_id?: string | null
          created_at?: string
          effective_from?: string
          effective_until?: string | null
          id?: string
          is_active?: boolean
          maker_checker_required?: boolean
          maximum_amount?: number | null
          minimum_amount?: number
          required_role: string
          transaction_type: string
          updated_at?: string
        }
        Update: {
          approval_level?: number
          branch_id?: string | null
          created_at?: string
          effective_from?: string
          effective_until?: string | null
          id?: string
          is_active?: boolean
          maker_checker_required?: boolean
          maximum_amount?: number | null
          minimum_amount?: number
          required_role?: string
          transaction_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_approval_rules_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_event_changes: {
        Row: {
          audit_log_id: string
          created_at: string
          field_name: string
          id: string
          new_value: Json | null
          old_value: Json | null
        }
        Insert: {
          audit_log_id: string
          created_at?: string
          field_name: string
          id?: string
          new_value?: Json | null
          old_value?: Json | null
        }
        Update: {
          audit_log_id?: string
          created_at?: string
          field_name?: string
          id?: string
          new_value?: Json | null
          old_value?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_event_changes_audit_log_id_fkey"
            columns: ["audit_log_id"]
            isOneToOne: false
            referencedRelation: "audit_logs"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          action: string
          branch_id: string | null
          entity_id: string | null
          entity_type: string
          id: string
          ip_address: unknown
          metadata: Json
          new_data: Json | null
          occurred_at: string
          old_data: Json | null
          reason: string | null
          request_id: string | null
          role_code: string | null
          session_id: string | null
          transaction_id: string | null
          user_agent: string | null
          user_id: string | null
        }
        Insert: {
          action: string
          branch_id?: string | null
          entity_id?: string | null
          entity_type: string
          id?: string
          ip_address?: unknown
          metadata?: Json
          new_data?: Json | null
          occurred_at?: string
          old_data?: Json | null
          reason?: string | null
          request_id?: string | null
          role_code?: string | null
          session_id?: string | null
          transaction_id?: string | null
          user_agent?: string | null
          user_id?: string | null
        }
        Update: {
          action?: string
          branch_id?: string | null
          entity_id?: string | null
          entity_type?: string
          id?: string
          ip_address?: unknown
          metadata?: Json
          new_data?: Json | null
          occurred_at?: string
          old_data?: Json | null
          reason?: string | null
          request_id?: string | null
          role_code?: string | null
          session_id?: string | null
          transaction_id?: string | null
          user_agent?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_audit_logs_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_audit_logs_transaction"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_audit_logs_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      branches: {
        Row: {
          address: string | null
          branch_type: Database["bmt_db"]["Enums"]["branch_type"]
          code: string
          created_at: string
          email: string | null
          id: string
          is_active: boolean
          name: string
          parent_branch_id: string | null
          phone: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          branch_type?: Database["bmt_db"]["Enums"]["branch_type"]
          code: string
          created_at?: string
          email?: string | null
          id?: string
          is_active?: boolean
          name: string
          parent_branch_id?: string | null
          phone?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          branch_type?: Database["bmt_db"]["Enums"]["branch_type"]
          code?: string
          created_at?: string
          email?: string | null
          id?: string
          is_active?: boolean
          name?: string
          parent_branch_id?: string | null
          phone?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_branches_parent"
            columns: ["parent_branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      business_calendar: {
        Row: {
          branch_id: string | null
          calendar_date: string
          created_at: string
          cut_off_at: string | null
          holiday_name: string | null
          id: string
          is_business_day: boolean
        }
        Insert: {
          branch_id?: string | null
          calendar_date: string
          created_at?: string
          cut_off_at?: string | null
          holiday_name?: string | null
          id?: string
          is_business_day?: boolean
        }
        Update: {
          branch_id?: string | null
          calendar_date?: string
          created_at?: string
          cut_off_at?: string | null
          holiday_name?: string | null
          id?: string
          is_business_day?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "business_calendar_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      chart_of_accounts: {
        Row: {
          account_type: Database["bmt_db"]["Enums"]["coa_account_type"]
          allow_posting: boolean
          code: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          level: number
          name: string
          normal_balance: Database["bmt_db"]["Enums"]["normal_balance_type"]
          parent_id: string | null
          updated_at: string
        }
        Insert: {
          account_type: Database["bmt_db"]["Enums"]["coa_account_type"]
          allow_posting?: boolean
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          level?: number
          name: string
          normal_balance: Database["bmt_db"]["Enums"]["normal_balance_type"]
          parent_id?: string | null
          updated_at?: string
        }
        Update: {
          account_type?: Database["bmt_db"]["Enums"]["coa_account_type"]
          allow_posting?: boolean
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          level?: number
          name?: string
          normal_balance?: Database["bmt_db"]["Enums"]["normal_balance_type"]
          parent_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_chart_of_accounts_parent"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      credit_analyses: {
        Row: {
          analyst_notes: string | null
          analyzed_at: string
          analyzed_by: string
          business_expenses: number
          created_at: string
          debt_service_ratio: number
          disposable_income: number
          existing_installments: number
          id: string
          living_expenses: number
          loan_application_id: string
          monthly_income: number
          net_income: number
          other_income: number
          other_liabilities: number
          proposed_installment: number
          recommendation: string | null
          updated_at: string
        }
        Insert: {
          analyst_notes?: string | null
          analyzed_at?: string
          analyzed_by: string
          business_expenses?: number
          created_at?: string
          debt_service_ratio?: number
          disposable_income?: number
          existing_installments?: number
          id?: string
          living_expenses?: number
          loan_application_id: string
          monthly_income?: number
          net_income?: number
          other_income?: number
          other_liabilities?: number
          proposed_installment?: number
          recommendation?: string | null
          updated_at?: string
        }
        Update: {
          analyst_notes?: string | null
          analyzed_at?: string
          analyzed_by?: string
          business_expenses?: number
          created_at?: string
          debt_service_ratio?: number
          disposable_income?: number
          existing_installments?: number
          id?: string
          living_expenses?: number
          loan_application_id?: string
          monthly_income?: number
          net_income?: number
          other_income?: number
          other_liabilities?: number
          proposed_installment?: number
          recommendation?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_credit_analyses_analyzed_by"
            columns: ["analyzed_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_credit_analyses_application"
            columns: ["loan_application_id"]
            isOneToOne: true
            referencedRelation: "loan_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_addresses: {
        Row: {
          address: string
          address_type: Database["bmt_db"]["Enums"]["address_type"]
          city: string | null
          created_at: string
          customer_id: string
          district: string | null
          id: string
          is_primary: boolean
          postal_code: string | null
          province: string | null
          updated_at: string
          village: string | null
        }
        Insert: {
          address: string
          address_type: Database["bmt_db"]["Enums"]["address_type"]
          city?: string | null
          created_at?: string
          customer_id: string
          district?: string | null
          id?: string
          is_primary?: boolean
          postal_code?: string | null
          province?: string | null
          updated_at?: string
          village?: string | null
        }
        Update: {
          address?: string
          address_type?: Database["bmt_db"]["Enums"]["address_type"]
          city?: string | null
          created_at?: string
          customer_id?: string
          district?: string | null
          id?: string
          is_primary?: boolean
          postal_code?: string | null
          province?: string | null
          updated_at?: string
          village?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_customer_addresses_customer"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_documents: {
        Row: {
          created_at: string
          customer_id: string
          document_number: string | null
          document_type: string
          expired_at: string | null
          id: string
          issued_at: string | null
          storage_bucket: string | null
          storage_path: string | null
          updated_at: string
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          created_at?: string
          customer_id: string
          document_number?: string | null
          document_type: string
          expired_at?: string | null
          id?: string
          issued_at?: string | null
          storage_bucket?: string | null
          storage_path?: string | null
          updated_at?: string
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          created_at?: string
          customer_id?: string
          document_number?: string | null
          document_type?: string
          expired_at?: string | null
          id?: string
          issued_at?: string | null
          storage_bucket?: string | null
          storage_path?: string | null
          updated_at?: string
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_customer_documents_customer"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_customer_documents_verified_by"
            columns: ["verified_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_marketing: {
        Row: {
          assigned_by: string | null
          assigned_from: string
          assigned_until: string | null
          created_at: string
          customer_id: string
          id: string
          is_active: boolean
          marketing_user_id: string
          notes: string | null
        }
        Insert: {
          assigned_by?: string | null
          assigned_from?: string
          assigned_until?: string | null
          created_at?: string
          customer_id: string
          id?: string
          is_active?: boolean
          marketing_user_id: string
          notes?: string | null
        }
        Update: {
          assigned_by?: string | null
          assigned_from?: string
          assigned_until?: string | null
          created_at?: string
          customer_id?: string
          id?: string
          is_active?: boolean
          marketing_user_id?: string
          notes?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_customer_marketing_assigned_by"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_customer_marketing_customer"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_customer_marketing_user"
            columns: ["marketing_user_id"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_risk_profiles: {
        Row: {
          created_at: string
          customer_id: string
          id: string
          pep_status: boolean
          review_due_at: string | null
          review_reason: string | null
          risk_level: string
          risk_score: number | null
          sanctions_status: string
          screening_checked_at: string | null
          screening_checked_by: string | null
          source_of_funds: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          customer_id: string
          id?: string
          pep_status?: boolean
          review_due_at?: string | null
          review_reason?: string | null
          risk_level?: string
          risk_score?: number | null
          sanctions_status?: string
          screening_checked_at?: string | null
          screening_checked_by?: string | null
          source_of_funds?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          customer_id?: string
          id?: string
          pep_status?: boolean
          review_due_at?: string | null
          review_reason?: string | null
          risk_level?: string
          risk_score?: number | null
          sanctions_status?: string
          screening_checked_at?: string | null
          screening_checked_by?: string | null
          source_of_funds?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_risk_profiles_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: true
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_status_history: {
        Row: {
          changed_at: string
          changed_by: string | null
          customer_id: string
          id: string
          metadata: Json
          new_status: Database["bmt_db"]["Enums"]["customer_status"]
          old_status: Database["bmt_db"]["Enums"]["customer_status"] | null
          reason: string | null
        }
        Insert: {
          changed_at?: string
          changed_by?: string | null
          customer_id: string
          id?: string
          metadata?: Json
          new_status: Database["bmt_db"]["Enums"]["customer_status"]
          old_status?: Database["bmt_db"]["Enums"]["customer_status"] | null
          reason?: string | null
        }
        Update: {
          changed_at?: string
          changed_by?: string | null
          customer_id?: string
          id?: string
          metadata?: Json
          new_status?: Database["bmt_db"]["Enums"]["customer_status"]
          old_status?: Database["bmt_db"]["Enums"]["customer_status"] | null
          reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "customer_status_history_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
        ]
      }
      customers: {
        Row: {
          auth_user_id: string | null
          birth_date: string | null
          birth_place: string | null
          branch_id: string
          cif_number: string
          created_at: string
          created_by: string | null
          email: string | null
          full_name: string
          gender: Database["bmt_db"]["Enums"]["gender_type"] | null
          id: string
          marital_status: string | null
          monthly_income: number | null
          mother_name: string | null
          nik: string | null
          occupation: string | null
          phone: string | null
          registered_at: string | null
          status: Database["bmt_db"]["Enums"]["customer_status"]
          updated_at: string
        }
        Insert: {
          auth_user_id?: string | null
          birth_date?: string | null
          birth_place?: string | null
          branch_id: string
          cif_number: string
          created_at?: string
          created_by?: string | null
          email?: string | null
          full_name: string
          gender?: Database["bmt_db"]["Enums"]["gender_type"] | null
          id?: string
          marital_status?: string | null
          monthly_income?: number | null
          mother_name?: string | null
          nik?: string | null
          occupation?: string | null
          phone?: string | null
          registered_at?: string | null
          status?: Database["bmt_db"]["Enums"]["customer_status"]
          updated_at?: string
        }
        Update: {
          auth_user_id?: string | null
          birth_date?: string | null
          birth_place?: string | null
          branch_id?: string
          cif_number?: string
          created_at?: string
          created_by?: string | null
          email?: string | null
          full_name?: string
          gender?: Database["bmt_db"]["Enums"]["gender_type"] | null
          id?: string
          marital_status?: string | null
          monthly_income?: number | null
          mother_name?: string | null
          nik?: string | null
          occupation?: string | null
          phone?: string | null
          registered_at?: string | null
          status?: Database["bmt_db"]["Enums"]["customer_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_customers_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_customers_created_by"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      deposit_accounts: {
        Row: {
          aro_type: Database["bmt_db"]["Enums"]["deposit_aro_type"]
          created_at: string
          deposit_status: Database["bmt_db"]["Enums"]["deposit_status"]
          financial_account_id: string
          maturity_date: string
          principal_amount: number
          profit_rate: number
          settlement_savings_account_id: string
          start_date: string
          terminated_at: string | null
          termination_reason: string | null
          updated_at: string
        }
        Insert: {
          aro_type?: Database["bmt_db"]["Enums"]["deposit_aro_type"]
          created_at?: string
          deposit_status?: Database["bmt_db"]["Enums"]["deposit_status"]
          financial_account_id: string
          maturity_date: string
          principal_amount: number
          profit_rate?: number
          settlement_savings_account_id: string
          start_date: string
          terminated_at?: string | null
          termination_reason?: string | null
          updated_at?: string
        }
        Update: {
          aro_type?: Database["bmt_db"]["Enums"]["deposit_aro_type"]
          created_at?: string
          deposit_status?: Database["bmt_db"]["Enums"]["deposit_status"]
          financial_account_id?: string
          maturity_date?: string
          principal_amount?: number
          profit_rate?: number
          settlement_savings_account_id?: string
          start_date?: string
          terminated_at?: string | null
          termination_reason?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_deposit_accounts_financial"
            columns: ["financial_account_id"]
            isOneToOne: true
            referencedRelation: "financial_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_deposit_accounts_settlement"
            columns: ["settlement_savings_account_id"]
            isOneToOne: false
            referencedRelation: "savings_accounts"
            referencedColumns: ["financial_account_id"]
          },
        ]
      }
      deposit_ledger: {
        Row: {
          amount: number
          balance_after: number
          created_at: string
          deposit_account_id: string
          description: string | null
          entry_date: string
          entry_type: Database["bmt_db"]["Enums"]["ledger_entry_type"]
          id: string
          transaction_id: string
          value_date: string
        }
        Insert: {
          amount: number
          balance_after: number
          created_at?: string
          deposit_account_id: string
          description?: string | null
          entry_date: string
          entry_type: Database["bmt_db"]["Enums"]["ledger_entry_type"]
          id?: string
          transaction_id: string
          value_date: string
        }
        Update: {
          amount?: number
          balance_after?: number
          created_at?: string
          deposit_account_id?: string
          description?: string | null
          entry_date?: string
          entry_type?: Database["bmt_db"]["Enums"]["ledger_entry_type"]
          id?: string
          transaction_id?: string
          value_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_deposit_ledger_account"
            columns: ["deposit_account_id"]
            isOneToOne: false
            referencedRelation: "deposit_accounts"
            referencedColumns: ["financial_account_id"]
          },
          {
            foreignKeyName: "fk_deposit_ledger_transaction"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      deposit_products: {
        Row: {
          account_code: string
          allow_aro: boolean
          created_at: string
          default_aro_type: Database["bmt_db"]["Enums"]["deposit_aro_type"]
          early_withdrawal_allowed: boolean
          early_withdrawal_penalty: number
          liability_coa_id: string | null
          minimum_amount: number
          penalty_income_coa_id: string | null
          product_id: string
          profit_expense_coa_id: string | null
          profit_method: string
          profit_rate: number
          tenor_months: number
          updated_at: string
        }
        Insert: {
          account_code: string
          allow_aro?: boolean
          created_at?: string
          default_aro_type?: Database["bmt_db"]["Enums"]["deposit_aro_type"]
          early_withdrawal_allowed?: boolean
          early_withdrawal_penalty?: number
          liability_coa_id?: string | null
          minimum_amount?: number
          penalty_income_coa_id?: string | null
          product_id: string
          profit_expense_coa_id?: string | null
          profit_method?: string
          profit_rate?: number
          tenor_months: number
          updated_at?: string
        }
        Update: {
          account_code?: string
          allow_aro?: boolean
          created_at?: string
          default_aro_type?: Database["bmt_db"]["Enums"]["deposit_aro_type"]
          early_withdrawal_allowed?: boolean
          early_withdrawal_penalty?: number
          liability_coa_id?: string | null
          minimum_amount?: number
          penalty_income_coa_id?: string | null
          product_id?: string
          profit_expense_coa_id?: string | null
          profit_method?: string
          profit_rate?: number
          tenor_months?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_deposit_products_liability_coa"
            columns: ["liability_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_deposit_products_penalty_income_coa"
            columns: ["penalty_income_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_deposit_products_product"
            columns: ["product_id"]
            isOneToOne: true
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_deposit_products_profit_expense_coa"
            columns: ["profit_expense_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      fee_schedules: {
        Row: {
          amount: number | null
          branch_id: string | null
          calculation_type: string
          created_at: string
          created_by: string | null
          effective_from: string
          effective_until: string | null
          fee_code: string
          fee_name: string
          id: string
          is_active: boolean
          product_id: string | null
          rate: number | null
        }
        Insert: {
          amount?: number | null
          branch_id?: string | null
          calculation_type: string
          created_at?: string
          created_by?: string | null
          effective_from: string
          effective_until?: string | null
          fee_code: string
          fee_name: string
          id?: string
          is_active?: boolean
          product_id?: string | null
          rate?: number | null
        }
        Update: {
          amount?: number | null
          branch_id?: string | null
          calculation_type?: string
          created_at?: string
          created_by?: string | null
          effective_from?: string
          effective_until?: string | null
          fee_code?: string
          fee_name?: string
          id?: string
          is_active?: boolean
          product_id?: string | null
          rate?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "fee_schedules_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fee_schedules_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      financial_accounts: {
        Row: {
          account_number: string
          account_type: Database["bmt_db"]["Enums"]["financial_account_type"]
          branch_id: string
          closed_at: string | null
          closed_by: string | null
          created_at: string
          customer_id: string
          id: string
          opened_at: string | null
          opened_by: string | null
          product_id: string
          sequence_no: number
          status: Database["bmt_db"]["Enums"]["account_status"]
          updated_at: string
        }
        Insert: {
          account_number: string
          account_type: Database["bmt_db"]["Enums"]["financial_account_type"]
          branch_id: string
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          customer_id: string
          id?: string
          opened_at?: string | null
          opened_by?: string | null
          product_id: string
          sequence_no: number
          status?: Database["bmt_db"]["Enums"]["account_status"]
          updated_at?: string
        }
        Update: {
          account_number?: string
          account_type?: Database["bmt_db"]["Enums"]["financial_account_type"]
          branch_id?: string
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          customer_id?: string
          id?: string
          opened_at?: string | null
          opened_by?: string | null
          product_id?: string
          sequence_no?: number
          status?: Database["bmt_db"]["Enums"]["account_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_financial_accounts_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_financial_accounts_closed_by"
            columns: ["closed_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_financial_accounts_customer"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_financial_accounts_opened_by"
            columns: ["opened_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_financial_accounts_product"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      financial_mutation_requests: {
        Row: {
          actor_id: string
          completed_at: string | null
          created_at: string
          expires_at: string
          id: string
          idempotency_key: string
          operation: string
          request_hash: string | null
          response_code: number | null
          result_id: string | null
          status: string
        }
        Insert: {
          actor_id: string
          completed_at?: string | null
          created_at?: string
          expires_at?: string
          id?: string
          idempotency_key: string
          operation: string
          request_hash?: string | null
          response_code?: number | null
          result_id?: string | null
          status?: string
        }
        Update: {
          actor_id?: string
          completed_at?: string | null
          created_at?: string
          expires_at?: string
          id?: string
          idempotency_key?: string
          operation?: string
          request_hash?: string | null
          response_code?: number | null
          result_id?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "financial_mutation_requests_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      fiscal_periods: {
        Row: {
          closed_at: string | null
          closed_by: string | null
          created_at: string
          end_date: string
          fiscal_year: number
          id: string
          period_no: number
          start_date: string
          status: Database["bmt_db"]["Enums"]["fiscal_period_status"]
          updated_at: string
        }
        Insert: {
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          end_date: string
          fiscal_year: number
          id?: string
          period_no: number
          start_date: string
          status?: Database["bmt_db"]["Enums"]["fiscal_period_status"]
          updated_at?: string
        }
        Update: {
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          end_date?: string
          fiscal_year?: number
          id?: string
          period_no?: number
          start_date?: string
          status?: Database["bmt_db"]["Enums"]["fiscal_period_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_fiscal_periods_closed_by"
            columns: ["closed_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      idempotency_keys: {
        Row: {
          actor_id: string | null
          channel: string
          completed_at: string | null
          created_at: string
          id: string
          idempotency_key: string
          operation: string
          request_hash: string | null
          response_payload: Json | null
          status: string
        }
        Insert: {
          actor_id?: string | null
          channel: string
          completed_at?: string | null
          created_at?: string
          id?: string
          idempotency_key: string
          operation: string
          request_hash?: string | null
          response_payload?: Json | null
          status?: string
        }
        Update: {
          actor_id?: string | null
          channel?: string
          completed_at?: string | null
          created_at?: string
          id?: string
          idempotency_key?: string
          operation?: string
          request_hash?: string | null
          response_payload?: Json | null
          status?: string
        }
        Relationships: []
      }
      installment_payments: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          loan_schedule_id: string
          margin_amount: number
          other_amount: number
          paid_at: string
          penalty_amount: number
          principal_amount: number
          transaction_id: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          loan_schedule_id: string
          margin_amount?: number
          other_amount?: number
          paid_at?: string
          penalty_amount?: number
          principal_amount?: number
          transaction_id?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          loan_schedule_id?: string
          margin_amount?: number
          other_amount?: number
          paid_at?: string
          penalty_amount?: number
          principal_amount?: number
          transaction_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_installment_payments_created_by"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_installment_payments_schedule"
            columns: ["loan_schedule_id"]
            isOneToOne: false
            referencedRelation: "loan_schedules"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_installment_payments_transaction"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      journal_entries: {
        Row: {
          branch_id: string
          created_at: string
          created_by: string | null
          description: string
          fiscal_period_id: string
          id: string
          journal_date: string
          journal_number: string
          posted_at: string | null
          posted_by: string | null
          reversal_journal_id: string | null
          status: Database["bmt_db"]["Enums"]["journal_status"]
          transaction_id: string
        }
        Insert: {
          branch_id: string
          created_at?: string
          created_by?: string | null
          description: string
          fiscal_period_id: string
          id?: string
          journal_date: string
          journal_number: string
          posted_at?: string | null
          posted_by?: string | null
          reversal_journal_id?: string | null
          status?: Database["bmt_db"]["Enums"]["journal_status"]
          transaction_id: string
        }
        Update: {
          branch_id?: string
          created_at?: string
          created_by?: string | null
          description?: string
          fiscal_period_id?: string
          id?: string
          journal_date?: string
          journal_number?: string
          posted_at?: string | null
          posted_by?: string | null
          reversal_journal_id?: string | null
          status?: Database["bmt_db"]["Enums"]["journal_status"]
          transaction_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_journal_entries_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_entries_created_by"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_entries_period"
            columns: ["fiscal_period_id"]
            isOneToOne: false
            referencedRelation: "fiscal_periods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_entries_posted_by"
            columns: ["posted_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_entries_reversal"
            columns: ["reversal_journal_id"]
            isOneToOne: false
            referencedRelation: "general_ledger"
            referencedColumns: ["journal_entry_id"]
          },
          {
            foreignKeyName: "fk_journal_entries_reversal"
            columns: ["reversal_journal_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_entries_transaction"
            columns: ["transaction_id"]
            isOneToOne: true
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      journal_lines: {
        Row: {
          coa_id: string
          created_at: string
          credit: number
          customer_id: string | null
          debit: number
          description: string | null
          financial_account_id: string | null
          id: string
          journal_entry_id: string
          line_no: number
        }
        Insert: {
          coa_id: string
          created_at?: string
          credit?: number
          customer_id?: string | null
          debit?: number
          description?: string | null
          financial_account_id?: string | null
          id?: string
          journal_entry_id: string
          line_no: number
        }
        Update: {
          coa_id?: string
          created_at?: string
          credit?: number
          customer_id?: string | null
          debit?: number
          description?: string | null
          financial_account_id?: string | null
          id?: string
          journal_entry_id?: string
          line_no?: number
        }
        Relationships: [
          {
            foreignKeyName: "fk_journal_lines_coa"
            columns: ["coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_lines_customer"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_lines_entry"
            columns: ["journal_entry_id"]
            isOneToOne: false
            referencedRelation: "general_ledger"
            referencedColumns: ["journal_entry_id"]
          },
          {
            foreignKeyName: "fk_journal_lines_entry"
            columns: ["journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_lines_financial_account"
            columns: ["financial_account_id"]
            isOneToOne: false
            referencedRelation: "financial_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      loan_accounts: {
        Row: {
          application_id: string
          created_at: string
          disbursement_amount: number
          disbursement_date: string | null
          financial_account_id: string
          loan_status: Database["bmt_db"]["Enums"]["loan_account_status"]
          margin_amount: number
          maturity_date: string | null
          outstanding_margin: number
          outstanding_penalty: number
          outstanding_principal: number
          principal_amount: number
          rate: number
          savings_account_id: string
          tenor_months: number
          updated_at: string
        }
        Insert: {
          application_id: string
          created_at?: string
          disbursement_amount?: number
          disbursement_date?: string | null
          financial_account_id: string
          loan_status?: Database["bmt_db"]["Enums"]["loan_account_status"]
          margin_amount?: number
          maturity_date?: string | null
          outstanding_margin?: number
          outstanding_penalty?: number
          outstanding_principal?: number
          principal_amount: number
          rate?: number
          savings_account_id: string
          tenor_months: number
          updated_at?: string
        }
        Update: {
          application_id?: string
          created_at?: string
          disbursement_amount?: number
          disbursement_date?: string | null
          financial_account_id?: string
          loan_status?: Database["bmt_db"]["Enums"]["loan_account_status"]
          margin_amount?: number
          maturity_date?: string | null
          outstanding_margin?: number
          outstanding_penalty?: number
          outstanding_principal?: number
          principal_amount?: number
          rate?: number
          savings_account_id?: string
          tenor_months?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_loan_accounts_application"
            columns: ["application_id"]
            isOneToOne: true
            referencedRelation: "loan_applications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_accounts_financial"
            columns: ["financial_account_id"]
            isOneToOne: true
            referencedRelation: "financial_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_accounts_savings"
            columns: ["savings_account_id"]
            isOneToOne: false
            referencedRelation: "savings_accounts"
            referencedColumns: ["financial_account_id"]
          },
        ]
      }
      loan_application_status_history: {
        Row: {
          changed_at: string
          changed_by: string | null
          id: string
          loan_application_id: string
          metadata: Json
          new_status: Database["bmt_db"]["Enums"]["loan_application_status"]
          old_status:
            | Database["bmt_db"]["Enums"]["loan_application_status"]
            | null
          reason: string | null
        }
        Insert: {
          changed_at?: string
          changed_by?: string | null
          id?: string
          loan_application_id: string
          metadata?: Json
          new_status: Database["bmt_db"]["Enums"]["loan_application_status"]
          old_status?:
            | Database["bmt_db"]["Enums"]["loan_application_status"]
            | null
          reason?: string | null
        }
        Update: {
          changed_at?: string
          changed_by?: string | null
          id?: string
          loan_application_id?: string
          metadata?: Json
          new_status?: Database["bmt_db"]["Enums"]["loan_application_status"]
          old_status?:
            | Database["bmt_db"]["Enums"]["loan_application_status"]
            | null
          reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "loan_application_status_history_loan_application_id_fkey"
            columns: ["loan_application_id"]
            isOneToOne: false
            referencedRelation: "loan_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      loan_applications: {
        Row: {
          application_number: string
          branch_id: string
          created_at: string
          created_by: string | null
          customer_id: string
          decided_at: string | null
          id: string
          admin_fee_snapshot: number | null
          idempotency_key: string | null
          installment_amount_snapshot: number | null
          loan_product_id: string
          loan_product_version_id: string | null
          margin_amount_snapshot: number | null
          margin_rate_snapshot: number | null
          selling_price_snapshot: number | null
          simulation_snapshot: Json | null
          marketing_user_id: string | null
          purpose: string
          requested_amount: number
          requested_tenor_months: number
          savings_account_id: string
          status: Database["bmt_db"]["Enums"]["loan_application_status"]
          submitted_at: string | null
          updated_at: string
        }
        Insert: {
          application_number: string
          branch_id: string
          created_at?: string
          created_by?: string | null
          customer_id: string
          decided_at?: string | null
          id?: string
          admin_fee_snapshot?: number | null
          idempotency_key?: string | null
          installment_amount_snapshot?: number | null
          loan_product_id: string
          loan_product_version_id?: string | null
          margin_amount_snapshot?: number | null
          margin_rate_snapshot?: number | null
          selling_price_snapshot?: number | null
          simulation_snapshot?: Json | null
          marketing_user_id?: string | null
          purpose: string
          requested_amount: number
          requested_tenor_months: number
          savings_account_id: string
          status?: Database["bmt_db"]["Enums"]["loan_application_status"]
          submitted_at?: string | null
          updated_at?: string
        }
        Update: {
          application_number?: string
          branch_id?: string
          created_at?: string
          created_by?: string | null
          customer_id?: string
          decided_at?: string | null
          id?: string
          admin_fee_snapshot?: number | null
          idempotency_key?: string | null
          installment_amount_snapshot?: number | null
          loan_product_id?: string
          loan_product_version_id?: string | null
          margin_amount_snapshot?: number | null
          margin_rate_snapshot?: number | null
          selling_price_snapshot?: number | null
          simulation_snapshot?: Json | null
          marketing_user_id?: string | null
          purpose?: string
          requested_amount?: number
          requested_tenor_months?: number
          savings_account_id?: string
          status?: Database["bmt_db"]["Enums"]["loan_application_status"]
          submitted_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_loan_applications_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_applications_created_by"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_applications_customer"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_applications_marketing"
            columns: ["marketing_user_id"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_applications_product"
            columns: ["loan_product_id"]
            isOneToOne: false
            referencedRelation: "loan_products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "fk_loan_applications_savings"
            columns: ["savings_account_id"]
            isOneToOne: false
            referencedRelation: "savings_accounts"
            referencedColumns: ["financial_account_id"]
          },
        ]
      }
      loan_collaterals: {
        Row: {
          appraised_value: number | null
          collateral_type: string
          created_at: string
          description: string
          document_number: string | null
          estimated_value: number | null
          id: string
          loan_application_id: string
          ownership_name: string | null
          status: Database["bmt_db"]["Enums"]["record_status"]
          storage_bucket: string | null
          storage_path: string | null
          updated_at: string
        }
        Insert: {
          appraised_value?: number | null
          collateral_type: string
          created_at?: string
          description: string
          document_number?: string | null
          estimated_value?: number | null
          id?: string
          loan_application_id: string
          ownership_name?: string | null
          status?: Database["bmt_db"]["Enums"]["record_status"]
          storage_bucket?: string | null
          storage_path?: string | null
          updated_at?: string
        }
        Update: {
          appraised_value?: number | null
          collateral_type?: string
          created_at?: string
          description?: string
          document_number?: string | null
          estimated_value?: number | null
          id?: string
          loan_application_id?: string
          ownership_name?: string | null
          status?: Database["bmt_db"]["Enums"]["record_status"]
          storage_bucket?: string | null
          storage_path?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_loan_collaterals_application"
            columns: ["loan_application_id"]
            isOneToOne: false
            referencedRelation: "loan_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      loan_ledger: {
        Row: {
          amount: number
          balance_after: number
          component: Database["bmt_db"]["Enums"]["loan_ledger_component"]
          created_at: string
          description: string | null
          entry_date: string
          entry_type: Database["bmt_db"]["Enums"]["ledger_entry_type"]
          id: string
          loan_account_id: string
          transaction_id: string
          value_date: string
        }
        Insert: {
          amount: number
          balance_after: number
          component: Database["bmt_db"]["Enums"]["loan_ledger_component"]
          created_at?: string
          description?: string | null
          entry_date: string
          entry_type: Database["bmt_db"]["Enums"]["ledger_entry_type"]
          id?: string
          loan_account_id: string
          transaction_id: string
          value_date: string
        }
        Update: {
          amount?: number
          balance_after?: number
          component?: Database["bmt_db"]["Enums"]["loan_ledger_component"]
          created_at?: string
          description?: string | null
          entry_date?: string
          entry_type?: Database["bmt_db"]["Enums"]["ledger_entry_type"]
          id?: string
          loan_account_id?: string
          transaction_id?: string
          value_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_loan_ledger_account"
            columns: ["loan_account_id"]
            isOneToOne: false
            referencedRelation: "loan_accounts"
            referencedColumns: ["financial_account_id"]
          },
          {
            foreignKeyName: "fk_loan_ledger_transaction"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      loan_products: {
        Row: {
          akad_code: string
          admin_fee: number
          admin_fee_type: string
          admin_fee_value: number
          calculation_method: string
          admin_income_coa_id: string | null
          contract_type: Database["bmt_db"]["Enums"]["contract_type"]
          created_at: string
          grace_period_days: number
          impairment_coa_id: string | null
          installment_method: string
          insurance_fee_type: string
          insurance_fee_value: number
          loan_code: string
          margin_income_coa_id: string | null
          maximum_principal: number | null
          maximum_tenor_months: number
          margin_rate: number
          margin_type: string
          minimum_principal: number
          minimum_tenor_months: number
          penalty_income_coa_id: string | null
          penalty_rate: number
          product_id: string
          provision_rate: number
          rate: number
          rate_type: string
          tenor_options: number[]
          receivable_coa_id: string | null
          require_collateral: boolean
          require_manager_approval: boolean
          updated_at: string
        }
        Insert: {
          admin_fee?: number
          admin_income_coa_id?: string | null
          contract_type?: Database["bmt_db"]["Enums"]["contract_type"]
          created_at?: string
          grace_period_days?: number
          impairment_coa_id?: string | null
          installment_method?: string
          loan_code: string
          margin_income_coa_id?: string | null
          maximum_principal?: number | null
          maximum_tenor_months: number
          minimum_principal?: number
          minimum_tenor_months?: number
          penalty_income_coa_id?: string | null
          penalty_rate?: number
          product_id: string
          provision_rate?: number
          rate?: number
          rate_type?: string
          receivable_coa_id?: string | null
          require_collateral?: boolean
          require_manager_approval?: boolean
          updated_at?: string
        }
        Update: {
          admin_fee?: number
          admin_income_coa_id?: string | null
          contract_type?: Database["bmt_db"]["Enums"]["contract_type"]
          created_at?: string
          grace_period_days?: number
          impairment_coa_id?: string | null
          installment_method?: string
          loan_code?: string
          margin_income_coa_id?: string | null
          maximum_principal?: number | null
          maximum_tenor_months?: number
          minimum_principal?: number
          minimum_tenor_months?: number
          penalty_income_coa_id?: string | null
          penalty_rate?: number
          product_id?: string
          provision_rate?: number
          rate?: number
          rate_type?: string
          receivable_coa_id?: string | null
          require_collateral?: boolean
          require_manager_approval?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_loan_products_admin_income_coa"
            columns: ["admin_income_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_products_impairment_coa"
            columns: ["impairment_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_products_margin_income_coa"
            columns: ["margin_income_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_products_penalty_income_coa"
            columns: ["penalty_income_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_products_product"
            columns: ["product_id"]
            isOneToOne: true
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_loan_products_receivable_coa"
            columns: ["receivable_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      loan_schedules: {
        Row: {
          created_at: string
          days_overdue: number
          due_date: string
          id: string
          installment_no: number
          loan_account_id: string
          margin_due: number
          margin_paid: number
          opening_principal: number
          other_due: number
          other_paid: number
          paid_at: string | null
          penalty_paid: number
          principal_due: number
          principal_paid: number
          status: Database["bmt_db"]["Enums"]["installment_status"]
          total_due: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          days_overdue?: number
          due_date: string
          id?: string
          installment_no: number
          loan_account_id: string
          margin_due?: number
          margin_paid?: number
          opening_principal: number
          other_due?: number
          other_paid?: number
          paid_at?: string | null
          penalty_paid?: number
          principal_due?: number
          principal_paid?: number
          status?: Database["bmt_db"]["Enums"]["installment_status"]
          total_due: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          days_overdue?: number
          due_date?: string
          id?: string
          installment_no?: number
          loan_account_id?: string
          margin_due?: number
          margin_paid?: number
          opening_principal?: number
          other_due?: number
          other_paid?: number
          paid_at?: string | null
          penalty_paid?: number
          principal_due?: number
          principal_paid?: number
          status?: Database["bmt_db"]["Enums"]["installment_status"]
          total_due?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_loan_schedules_account"
            columns: ["loan_account_id"]
            isOneToOne: false
            referencedRelation: "loan_accounts"
            referencedColumns: ["financial_account_id"]
          },
        ]
      }
      number_sequences: {
        Row: {
          branch_id: string
          current_value: number
          id: string
          loan_code: string
          padding: number
          period_key: string
          product_code: string
          reset_policy: Database["bmt_db"]["Enums"]["sequence_reset_policy"]
          sequence_type: Database["bmt_db"]["Enums"]["sequence_type"]
          updated_at: string
        }
        Insert: {
          branch_id: string
          current_value?: number
          id?: string
          loan_code?: string
          padding?: number
          period_key?: string
          product_code?: string
          reset_policy?: Database["bmt_db"]["Enums"]["sequence_reset_policy"]
          sequence_type: Database["bmt_db"]["Enums"]["sequence_type"]
          updated_at?: string
        }
        Update: {
          branch_id?: string
          current_value?: number
          id?: string
          loan_code?: string
          padding?: number
          period_key?: string
          product_code?: string
          reset_policy?: Database["bmt_db"]["Enums"]["sequence_reset_policy"]
          sequence_type?: Database["bmt_db"]["Enums"]["sequence_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_number_sequences_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_addresses: {
        Row: {
          address: string
          address_type: Database["bmt_db"]["Enums"]["address_type"]
          application_id: string
          city: string | null
          created_at: string
          district: string | null
          id: string
          is_primary: boolean
          postal_code: string | null
          province: string | null
          rt: string | null
          rw: string | null
          updated_at: string
          village: string | null
        }
        Insert: {
          address: string
          address_type: Database["bmt_db"]["Enums"]["address_type"]
          application_id: string
          city?: string | null
          created_at?: string
          district?: string | null
          id?: string
          is_primary?: boolean
          postal_code?: string | null
          province?: string | null
          rt?: string | null
          rw?: string | null
          updated_at?: string
          village?: string | null
        }
        Update: {
          address?: string
          address_type?: Database["bmt_db"]["Enums"]["address_type"]
          application_id?: string
          city?: string | null
          created_at?: string
          district?: string | null
          id?: string
          is_primary?: boolean
          postal_code?: string | null
          province?: string | null
          rt?: string | null
          rw?: string | null
          updated_at?: string
          village?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_onboarding_address_app"
            columns: ["application_id"]
            isOneToOne: false
            referencedRelation: "onboarding_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_applications: {
        Row: {
          applicant_user_id: string | null
          approved_at: string | null
          birth_date: string | null
          birth_place: string | null
          branch_id: string
          completed_at: string | null
          created_at: string
          created_by: string | null
          customer_id: string | null
          education: string | null
          email: string | null
          emergency_contact_name: string | null
          emergency_contact_phone: string | null
          emergency_relationship: string | null
          employer_name: string | null
          form_version: number
          full_name: string | null
          gender: Database["bmt_db"]["Enums"]["gender_type"] | null
          id: string
          identity_expired_at: string | null
          identity_type: string
          manager_reviewed_at: string | null
          manager_reviewed_by: string | null
          marital_status: string | null
          monthly_expense: number | null
          monthly_income: number | null
          mother_name: string | null
          nationality: string
          nik: string | null
          npwp: string | null
          occupation: string | null
          phone: string | null
          position_name: string | null
          purpose_of_account: string | null
          rejection_reason: string | null
          religion: string | null
          return_reason: string | null
          source_of_funds: string | null
          status: Database["bmt_db"]["Enums"]["onboarding_status"]
          submitted_at: string | null
          teller_reviewed_at: string | null
          teller_reviewed_by: string | null
          updated_at: string
        }
        Insert: {
          applicant_user_id?: string | null
          approved_at?: string | null
          birth_date?: string | null
          birth_place?: string | null
          branch_id: string
          completed_at?: string | null
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          education?: string | null
          email?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          emergency_relationship?: string | null
          employer_name?: string | null
          form_version?: number
          full_name?: string | null
          gender?: Database["bmt_db"]["Enums"]["gender_type"] | null
          id?: string
          identity_expired_at?: string | null
          identity_type?: string
          manager_reviewed_at?: string | null
          manager_reviewed_by?: string | null
          marital_status?: string | null
          monthly_expense?: number | null
          monthly_income?: number | null
          mother_name?: string | null
          nationality?: string
          nik?: string | null
          npwp?: string | null
          occupation?: string | null
          phone?: string | null
          position_name?: string | null
          purpose_of_account?: string | null
          rejection_reason?: string | null
          religion?: string | null
          return_reason?: string | null
          source_of_funds?: string | null
          status?: Database["bmt_db"]["Enums"]["onboarding_status"]
          submitted_at?: string | null
          teller_reviewed_at?: string | null
          teller_reviewed_by?: string | null
          updated_at?: string
        }
        Update: {
          applicant_user_id?: string | null
          approved_at?: string | null
          birth_date?: string | null
          birth_place?: string | null
          branch_id?: string
          completed_at?: string | null
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          education?: string | null
          email?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          emergency_relationship?: string | null
          employer_name?: string | null
          form_version?: number
          full_name?: string | null
          gender?: Database["bmt_db"]["Enums"]["gender_type"] | null
          id?: string
          identity_expired_at?: string | null
          identity_type?: string
          manager_reviewed_at?: string | null
          manager_reviewed_by?: string | null
          marital_status?: string | null
          monthly_expense?: number | null
          monthly_income?: number | null
          mother_name?: string | null
          nationality?: string
          nik?: string | null
          npwp?: string | null
          occupation?: string | null
          phone?: string | null
          position_name?: string | null
          purpose_of_account?: string | null
          rejection_reason?: string | null
          religion?: string | null
          return_reason?: string | null
          source_of_funds?: string | null
          status?: Database["bmt_db"]["Enums"]["onboarding_status"]
          submitted_at?: string | null
          teller_reviewed_at?: string | null
          teller_reviewed_by?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_onboarding_app_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_onboarding_app_created_by"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_onboarding_app_customer"
            columns: ["customer_id"]
            isOneToOne: true
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_onboarding_app_manager"
            columns: ["manager_reviewed_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_onboarding_app_teller"
            columns: ["teller_reviewed_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_bank_accounts: {
        Row: {
          account_name: string | null
          account_number: string | null
          account_type: string | null
          application_id: string
          bank_name: string
          created_at: string
          credit_card_class: string | null
          id: string
          is_primary: boolean
          updated_at: string
        }
        Insert: {
          account_name?: string | null
          account_number?: string | null
          account_type?: string | null
          application_id: string
          bank_name: string
          created_at?: string
          credit_card_class?: string | null
          id?: string
          is_primary?: boolean
          updated_at?: string
        }
        Update: {
          account_name?: string | null
          account_number?: string | null
          account_type?: string | null
          application_id?: string
          bank_name?: string
          created_at?: string
          credit_card_class?: string | null
          id?: string
          is_primary?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_onboarding_bank_app"
            columns: ["application_id"]
            isOneToOne: false
            referencedRelation: "onboarding_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_documents: {
        Row: {
          application_id: string
          created_at: string
          document_number: string | null
          document_type: string
          expired_at: string | null
          file_size_bytes: number | null
          id: string
          issued_at: string | null
          mime_type: string | null
          sha256: string | null
          status: Database["bmt_db"]["Enums"]["onboarding_document_status"]
          storage_bucket: string
          storage_path: string
          updated_at: string
          verification_notes: string | null
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          application_id: string
          created_at?: string
          document_number?: string | null
          document_type: string
          expired_at?: string | null
          file_size_bytes?: number | null
          id?: string
          issued_at?: string | null
          mime_type?: string | null
          sha256?: string | null
          status?: Database["bmt_db"]["Enums"]["onboarding_document_status"]
          storage_bucket: string
          storage_path: string
          updated_at?: string
          verification_notes?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          application_id?: string
          created_at?: string
          document_number?: string | null
          document_type?: string
          expired_at?: string | null
          file_size_bytes?: number | null
          id?: string
          issued_at?: string | null
          mime_type?: string | null
          sha256?: string | null
          status?: Database["bmt_db"]["Enums"]["onboarding_document_status"]
          storage_bucket?: string
          storage_path?: string
          updated_at?: string
          verification_notes?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_onboarding_document_app"
            columns: ["application_id"]
            isOneToOne: false
            referencedRelation: "onboarding_applications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_onboarding_document_verifier"
            columns: ["verified_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_employment: {
        Row: {
          application_id: string
          business_name: string | null
          business_type: string | null
          created_at: string
          employer_name: string | null
          employment_type: string | null
          id: string
          income_source_detail: string | null
          monthly_income: number | null
          occupation: string | null
          office_address: string | null
          office_phone: string | null
          other_monthly_income: number | null
          position_name: string | null
          updated_at: string
          years_employed: number | null
          years_in_business: number | null
        }
        Insert: {
          application_id: string
          business_name?: string | null
          business_type?: string | null
          created_at?: string
          employer_name?: string | null
          employment_type?: string | null
          id?: string
          income_source_detail?: string | null
          monthly_income?: number | null
          occupation?: string | null
          office_address?: string | null
          office_phone?: string | null
          other_monthly_income?: number | null
          position_name?: string | null
          updated_at?: string
          years_employed?: number | null
          years_in_business?: number | null
        }
        Update: {
          application_id?: string
          business_name?: string | null
          business_type?: string | null
          created_at?: string
          employer_name?: string | null
          employment_type?: string | null
          id?: string
          income_source_detail?: string | null
          monthly_income?: number | null
          occupation?: string | null
          office_address?: string | null
          office_phone?: string | null
          other_monthly_income?: number | null
          position_name?: string | null
          updated_at?: string
          years_employed?: number | null
          years_in_business?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_onboarding_employment_app"
            columns: ["application_id"]
            isOneToOne: true
            referencedRelation: "onboarding_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_financial_profiles: {
        Row: {
          application_id: string
          created_at: string
          expected_monthly_tx_amount: number | null
          expected_monthly_tx_count: number | null
          id: string
          monthly_expense: number | null
          monthly_income: number | null
          source_of_funds: string | null
          source_of_wealth: string | null
          total_assets: number | null
          total_liabilities: number | null
          transaction_purpose: string | null
          updated_at: string
        }
        Insert: {
          application_id: string
          created_at?: string
          expected_monthly_tx_amount?: number | null
          expected_monthly_tx_count?: number | null
          id?: string
          monthly_expense?: number | null
          monthly_income?: number | null
          source_of_funds?: string | null
          source_of_wealth?: string | null
          total_assets?: number | null
          total_liabilities?: number | null
          transaction_purpose?: string | null
          updated_at?: string
        }
        Update: {
          application_id?: string
          created_at?: string
          expected_monthly_tx_amount?: number | null
          expected_monthly_tx_count?: number | null
          id?: string
          monthly_expense?: number | null
          monthly_income?: number | null
          source_of_funds?: string | null
          source_of_wealth?: string | null
          total_assets?: number | null
          total_liabilities?: number | null
          transaction_purpose?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_onboarding_financial_app"
            columns: ["application_id"]
            isOneToOne: true
            referencedRelation: "onboarding_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_product_requests: {
        Row: {
          application_id: string
          created_at: string
          destination_account: string | null
          id: string
          product_id: string
          profit_payment_method: string | null
          purpose: string | null
          requested_amount: number | null
          requested_tenor_months: number | null
          review_notes: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          rollover_type: string | null
          status: Database["bmt_db"]["Enums"]["onboarding_product_status"]
          updated_at: string
        }
        Insert: {
          application_id: string
          created_at?: string
          destination_account?: string | null
          id?: string
          product_id: string
          profit_payment_method?: string | null
          purpose?: string | null
          requested_amount?: number | null
          requested_tenor_months?: number | null
          review_notes?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          rollover_type?: string | null
          status?: Database["bmt_db"]["Enums"]["onboarding_product_status"]
          updated_at?: string
        }
        Update: {
          application_id?: string
          created_at?: string
          destination_account?: string | null
          id?: string
          product_id?: string
          profit_payment_method?: string | null
          purpose?: string | null
          requested_amount?: number | null
          requested_tenor_months?: number | null
          review_notes?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          rollover_type?: string | null
          status?: Database["bmt_db"]["Enums"]["onboarding_product_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_onboarding_product_app"
            columns: ["application_id"]
            isOneToOne: false
            referencedRelation: "onboarding_applications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_onboarding_product_master"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_onboarding_product_reviewer"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_signatures: {
        Row: {
          application_id: string
          created_at: string
          id: string
          invalidated_at: string | null
          invalidation_reason: string | null
          ip_address: unknown
          is_valid: boolean
          signature_sha256: string
          signed_at: string
          signed_version: number
          signer_role: Database["bmt_db"]["Enums"]["onboarding_signature_role"]
          signer_user_id: string
          storage_bucket: string
          storage_path: string
          user_agent: string | null
        }
        Insert: {
          application_id: string
          created_at?: string
          id?: string
          invalidated_at?: string | null
          invalidation_reason?: string | null
          ip_address?: unknown
          is_valid?: boolean
          signature_sha256: string
          signed_at?: string
          signed_version: number
          signer_role: Database["bmt_db"]["Enums"]["onboarding_signature_role"]
          signer_user_id: string
          storage_bucket: string
          storage_path: string
          user_agent?: string | null
        }
        Update: {
          application_id?: string
          created_at?: string
          id?: string
          invalidated_at?: string | null
          invalidation_reason?: string | null
          ip_address?: unknown
          is_valid?: boolean
          signature_sha256?: string
          signed_at?: string
          signed_version?: number
          signer_role?: Database["bmt_db"]["Enums"]["onboarding_signature_role"]
          signer_user_id?: string
          storage_bucket?: string
          storage_path?: string
          user_agent?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_onboarding_signature_app"
            columns: ["application_id"]
            isOneToOne: false
            referencedRelation: "onboarding_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_status_history: {
        Row: {
          application_id: string
          changed_at: string
          changed_by: string | null
          from_status: Database["bmt_db"]["Enums"]["onboarding_status"] | null
          id: string
          metadata: Json
          reason: string | null
          to_status: Database["bmt_db"]["Enums"]["onboarding_status"]
        }
        Insert: {
          application_id: string
          changed_at?: string
          changed_by?: string | null
          from_status?: Database["bmt_db"]["Enums"]["onboarding_status"] | null
          id?: string
          metadata?: Json
          reason?: string | null
          to_status: Database["bmt_db"]["Enums"]["onboarding_status"]
        }
        Update: {
          application_id?: string
          changed_at?: string
          changed_by?: string | null
          from_status?: Database["bmt_db"]["Enums"]["onboarding_status"] | null
          id?: string
          metadata?: Json
          reason?: string | null
          to_status?: Database["bmt_db"]["Enums"]["onboarding_status"]
        }
        Relationships: [
          {
            foreignKeyName: "fk_onboarding_history_app"
            columns: ["application_id"]
            isOneToOne: false
            referencedRelation: "onboarding_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      operational_days: {
        Row: {
          branch_id: string
          business_date: string
          closed_at: string | null
          closed_by: string | null
          closing_summary: Json
          id: string
          opened_at: string | null
          opened_by: string | null
          status: string
        }
        Insert: {
          branch_id: string
          business_date: string
          closed_at?: string | null
          closed_by?: string | null
          closing_summary?: Json
          id?: string
          opened_at?: string | null
          opened_by?: string | null
          status?: string
        }
        Update: {
          branch_id?: string
          business_date?: string
          closed_at?: string | null
          closed_by?: string | null
          closing_summary?: Json
          id?: string
          opened_at?: string | null
          opened_by?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "operational_days_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      operational_retention_policy: {
        Row: {
          archive_strategy: string
          partition_key: string | null
          retention_interval: string
          reviewed_at: string
          table_name: string
        }
        Insert: {
          archive_strategy: string
          partition_key?: string | null
          retention_interval: string
          reviewed_at?: string
          table_name: string
        }
        Update: {
          archive_strategy?: string
          partition_key?: string | null
          retention_interval?: string
          reviewed_at?: string
          table_name?: string
        }
        Relationships: []
      }
      permissions: {
        Row: {
          code: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          module: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          module: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          module?: string
          updated_at?: string
        }
        Relationships: []
      }
      products: {
        Row: {
          category: Database["bmt_db"]["Enums"]["product_category"]
          code: string
          created_at: string
          created_by: string | null
          currency: string
          description: string | null
          effective_from: string
          effective_until: string | null
          id: string
          is_active: boolean
          name: string
          terms_and_conditions: string | null
          updated_at: string
        }
        Insert: {
          category: Database["bmt_db"]["Enums"]["product_category"]
          code: string
          created_at?: string
          created_by?: string | null
          currency?: string
          description?: string | null
          effective_from?: string
          effective_until?: string | null
          id?: string
          is_active?: boolean
          name: string
          terms_and_conditions?: string | null
          updated_at?: string
        }
        Update: {
          category?: Database["bmt_db"]["Enums"]["product_category"]
          code?: string
          created_at?: string
          created_by?: string | null
          currency?: string
          description?: string | null
          effective_from?: string
          effective_until?: string | null
          id?: string
          is_active?: boolean
          name?: string
          terms_and_conditions?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_products_created_by"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      reconciliation_exceptions: {
        Row: {
          amount: number | null
          assigned_to: string | null
          branch_id: string | null
          created_at: string
          exception_type: string
          external_reference: string | null
          id: string
          metadata: Json
          resolution: string | null
          resolved_at: string | null
          resolved_by: string | null
          source_system: string
          status: string
          transaction_id: string | null
          updated_at: string
        }
        Insert: {
          amount?: number | null
          assigned_to?: string | null
          branch_id?: string | null
          created_at?: string
          exception_type: string
          external_reference?: string | null
          id?: string
          metadata?: Json
          resolution?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          source_system: string
          status?: string
          transaction_id?: string | null
          updated_at?: string
        }
        Update: {
          amount?: number | null
          assigned_to?: string | null
          branch_id?: string | null
          created_at?: string
          exception_type?: string
          external_reference?: string | null
          id?: string
          metadata?: Json
          resolution?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          source_system?: string
          status?: string
          transaction_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "reconciliation_exceptions_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reconciliation_exceptions_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          granted_at: string
          granted_by: string | null
          permission_id: string
          role_id: string
        }
        Insert: {
          granted_at?: string
          granted_by?: string | null
          permission_id: string
          role_id: string
        }
        Update: {
          granted_at?: string
          granted_by?: string | null
          permission_id?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_role_permissions_granted_by"
            columns: ["granted_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_role_permissions_permission"
            columns: ["permission_id"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_role_permissions_role"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          code: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          is_system: boolean
          name: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          is_system?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          is_system?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      savings_accounts: {
        Row: {
          available_balance: number
          blocked_balance: number
          created_at: string
          current_balance: number
          dormant_at: string | null
          financial_account_id: string
          last_transaction_at: string | null
          updated_at: string
        }
        Insert: {
          available_balance?: number
          blocked_balance?: number
          created_at?: string
          current_balance?: number
          dormant_at?: string | null
          financial_account_id: string
          last_transaction_at?: string | null
          updated_at?: string
        }
        Update: {
          available_balance?: number
          blocked_balance?: number
          created_at?: string
          current_balance?: number
          dormant_at?: string | null
          financial_account_id?: string
          last_transaction_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_savings_accounts_financial"
            columns: ["financial_account_id"]
            isOneToOne: true
            referencedRelation: "financial_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      savings_ledger: {
        Row: {
          account_id: string
          amount: number
          balance_after: number
          created_at: string
          description: string | null
          entry_date: string
          entry_type: Database["bmt_db"]["Enums"]["ledger_entry_type"]
          id: string
          transaction_id: string
          value_date: string
        }
        Insert: {
          account_id: string
          amount: number
          balance_after: number
          created_at?: string
          description?: string | null
          entry_date: string
          entry_type: Database["bmt_db"]["Enums"]["ledger_entry_type"]
          id?: string
          transaction_id: string
          value_date: string
        }
        Update: {
          account_id?: string
          amount?: number
          balance_after?: number
          created_at?: string
          description?: string | null
          entry_date?: string
          entry_type?: Database["bmt_db"]["Enums"]["ledger_entry_type"]
          id?: string
          transaction_id?: string
          value_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_savings_ledger_account"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "savings_accounts"
            referencedColumns: ["financial_account_id"]
          },
          {
            foreignKeyName: "fk_savings_ledger_transaction"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      savings_products: {
        Row: {
          account_code: string
          admin_fee: number
          admin_income_coa_id: string | null
          allow_negative_balance: boolean
          created_at: string
          dormant_after_days: number | null
          dormant_fee: number
          liability_coa_id: string | null
          maximum_deposit: number | null
          maximum_withdrawal: number | null
          minimum_balance: number
          minimum_deposit: number
          minimum_opening_balance: number
          minimum_monthly_deposit: number
          minimum_withdrawal: number
          product_id: string
          profit_expense_coa_id: string | null
          profit_sharing_rate: number
          updated_at: string
        }
        Insert: {
          account_code: string
          admin_fee?: number
          admin_income_coa_id?: string | null
          allow_negative_balance?: boolean
          created_at?: string
          dormant_after_days?: number | null
          dormant_fee?: number
          liability_coa_id?: string | null
          maximum_deposit?: number | null
          maximum_withdrawal?: number | null
          minimum_balance?: number
          minimum_deposit?: number
          minimum_opening_balance?: number
          minimum_monthly_deposit?: number
          minimum_withdrawal?: number
          product_id: string
          profit_expense_coa_id?: string | null
          profit_sharing_rate?: number
          updated_at?: string
        }
        Update: {
          account_code?: string
          admin_fee?: number
          admin_income_coa_id?: string | null
          allow_negative_balance?: boolean
          created_at?: string
          dormant_after_days?: number | null
          dormant_fee?: number
          liability_coa_id?: string | null
          maximum_deposit?: number | null
          maximum_withdrawal?: number | null
          minimum_balance?: number
          minimum_deposit?: number
          minimum_opening_balance?: number
          minimum_monthly_deposit?: number
          minimum_withdrawal?: number
          product_id?: string
          profit_expense_coa_id?: string | null
          profit_sharing_rate?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_savings_products_admin_income_coa"
            columns: ["admin_income_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_savings_products_liability_coa"
            columns: ["liability_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_savings_products_product"
            columns: ["product_id"]
            isOneToOne: true
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_savings_products_profit_expense_coa"
            columns: ["profit_expense_coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      teller_cash_movements: {
        Row: {
          amount: number
          cash_session_id: string
          created_at: string
          created_by: string
          description: string | null
          id: string
          movement_type: Database["bmt_db"]["Enums"]["cash_movement_type"]
          transaction_id: string | null
        }
        Insert: {
          amount: number
          cash_session_id: string
          created_at?: string
          created_by: string
          description?: string | null
          id?: string
          movement_type: Database["bmt_db"]["Enums"]["cash_movement_type"]
          transaction_id?: string | null
        }
        Update: {
          amount?: number
          cash_session_id?: string
          created_at?: string
          created_by?: string
          description?: string | null
          id?: string
          movement_type?: Database["bmt_db"]["Enums"]["cash_movement_type"]
          transaction_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_teller_cash_movements_created_by"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_teller_cash_movements_session"
            columns: ["cash_session_id"]
            isOneToOne: false
            referencedRelation: "teller_cash_sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_teller_cash_movements_transaction"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      teller_cash_sessions: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          branch_id: string
          business_date: string
          closed_at: string | null
          closing_notes: string | null
          created_at: string
          difference: number | null
          id: string
          opened_at: string
          opening_balance: number
          physical_closing_balance: number | null
          status: Database["bmt_db"]["Enums"]["cash_session_status"]
          system_closing_balance: number | null
          teller_user_id: string
          updated_at: string
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          branch_id: string
          business_date?: string
          closed_at?: string | null
          closing_notes?: string | null
          created_at?: string
          difference?: number | null
          id?: string
          opened_at?: string
          opening_balance?: number
          physical_closing_balance?: number | null
          status?: Database["bmt_db"]["Enums"]["cash_session_status"]
          system_closing_balance?: number | null
          teller_user_id: string
          updated_at?: string
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          branch_id?: string
          business_date?: string
          closed_at?: string | null
          closing_notes?: string | null
          created_at?: string
          difference?: number | null
          id?: string
          opened_at?: string
          opening_balance?: number
          physical_closing_balance?: number | null
          status?: Database["bmt_db"]["Enums"]["cash_session_status"]
          system_closing_balance?: number | null
          teller_user_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_teller_cash_sessions_approved_by"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_teller_cash_sessions_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_teller_cash_sessions_teller"
            columns: ["teller_user_id"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      transaction_receipts: {
        Row: {
          created_at: string
          first_printed_at: string | null
          id: string
          last_printed_at: string | null
          last_printed_by: string | null
          printed_count: number
          receipt_number: string
          template_type: string
          transaction_id: string
        }
        Insert: {
          created_at?: string
          first_printed_at?: string | null
          id?: string
          last_printed_at?: string | null
          last_printed_by?: string | null
          printed_count?: number
          receipt_number: string
          template_type?: string
          transaction_id: string
        }
        Update: {
          created_at?: string
          first_printed_at?: string | null
          id?: string
          last_printed_at?: string | null
          last_printed_by?: string | null
          printed_count?: number
          receipt_number?: string
          template_type?: string
          transaction_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_transaction_receipts_last_printed_by"
            columns: ["last_printed_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_transaction_receipts_transaction"
            columns: ["transaction_id"]
            isOneToOne: true
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      transactions: {
        Row: {
          amount: number
          approved_at: string | null
          approved_by: string | null
          branch_id: string
          channel: Database["bmt_db"]["Enums"]["transaction_channel"]
          created_at: string
          created_by: string | null
          currency: string
          customer_id: string | null
          description: string | null
          financial_account_id: string | null
          id: string
          idempotency_key: string | null
          posted_at: string | null
          posted_by: string | null
          reference_number: string | null
          reversed_transaction_id: string | null
          status: Database["bmt_db"]["Enums"]["transaction_status"]
          teller_session_id: string | null
          transaction_date: string
          transaction_number: string
          transaction_type: string
          value_date: string
        }
        Insert: {
          amount: number
          approved_at?: string | null
          approved_by?: string | null
          branch_id: string
          channel?: Database["bmt_db"]["Enums"]["transaction_channel"]
          created_at?: string
          created_by?: string | null
          currency?: string
          customer_id?: string | null
          description?: string | null
          financial_account_id?: string | null
          id?: string
          idempotency_key?: string | null
          posted_at?: string | null
          posted_by?: string | null
          reference_number?: string | null
          reversed_transaction_id?: string | null
          status?: Database["bmt_db"]["Enums"]["transaction_status"]
          teller_session_id?: string | null
          transaction_date?: string
          transaction_number: string
          transaction_type: string
          value_date?: string
        }
        Update: {
          amount?: number
          approved_at?: string | null
          approved_by?: string | null
          branch_id?: string
          channel?: Database["bmt_db"]["Enums"]["transaction_channel"]
          created_at?: string
          created_by?: string | null
          currency?: string
          customer_id?: string | null
          description?: string | null
          financial_account_id?: string | null
          id?: string
          idempotency_key?: string | null
          posted_at?: string | null
          posted_by?: string | null
          reference_number?: string | null
          reversed_transaction_id?: string | null
          status?: Database["bmt_db"]["Enums"]["transaction_status"]
          teller_session_id?: string | null
          transaction_date?: string
          transaction_number?: string
          transaction_type?: string
          value_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_transactions_approved_by"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_transactions_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_transactions_created_by"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_transactions_customer"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_transactions_financial_account"
            columns: ["financial_account_id"]
            isOneToOne: false
            referencedRelation: "financial_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_transactions_posted_by"
            columns: ["posted_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_transactions_reversal"
            columns: ["reversed_transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_transactions_teller_session"
            columns: ["teller_session_id"]
            isOneToOne: false
            referencedRelation: "teller_cash_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      user_branches: {
        Row: {
          assigned_at: string
          assigned_by: string | null
          branch_id: string
          is_primary: boolean
          user_id: string
        }
        Insert: {
          assigned_at?: string
          assigned_by?: string | null
          branch_id: string
          is_primary?: boolean
          user_id: string
        }
        Update: {
          assigned_at?: string
          assigned_by?: string | null
          branch_id?: string
          is_primary?: boolean
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_user_branches_assigned_by"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_user_branches_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_user_branches_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_profiles: {
        Row: {
          created_at: string
          email: string | null
          employee_no: string | null
          full_name: string
          id: string
          is_active: boolean
          last_login_at: string | null
          phone: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          email?: string | null
          employee_no?: string | null
          full_name: string
          id: string
          is_active?: boolean
          last_login_at?: string | null
          phone?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          email?: string | null
          employee_no?: string | null
          full_name?: string
          id?: string
          is_active?: boolean
          last_login_at?: string | null
          phone?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          assigned_by: string | null
          branch_id: string | null
          created_at: string
          id: string
          is_active: boolean
          role_id: string
          user_id: string
          valid_from: string
          valid_until: string | null
        }
        Insert: {
          assigned_by?: string | null
          branch_id?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          role_id: string
          user_id: string
          valid_from?: string
          valid_until?: string | null
        }
        Update: {
          assigned_by?: string | null
          branch_id?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          role_id?: string
          user_id?: string
          valid_from?: string
          valid_until?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_user_roles_assigned_by"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_user_roles_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_user_roles_role"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_user_roles_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      general_ledger: {
        Row: {
          account_type: Database["bmt_db"]["Enums"]["coa_account_type"] | null
          branch_code: string | null
          branch_id: string | null
          branch_name: string | null
          coa_code: string | null
          coa_id: string | null
          coa_name: string | null
          credit: number | null
          customer_id: string | null
          debit: number | null
          financial_account_id: string | null
          fiscal_period_id: string | null
          fiscal_year: number | null
          journal_date: string | null
          journal_description: string | null
          journal_entry_id: string | null
          journal_number: string | null
          line_description: string | null
          line_no: number | null
          normal_balance:
            | Database["bmt_db"]["Enums"]["normal_balance_type"]
            | null
          period_no: number | null
          posted_at: string | null
          transaction_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_journal_entries_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_entries_period"
            columns: ["fiscal_period_id"]
            isOneToOne: false
            referencedRelation: "fiscal_periods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_entries_transaction"
            columns: ["transaction_id"]
            isOneToOne: true
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_lines_coa"
            columns: ["coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_lines_customer"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_lines_financial_account"
            columns: ["financial_account_id"]
            isOneToOne: false
            referencedRelation: "financial_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      rls_policy_audit: {
        Row: {
          policy_count: number | null
          rls_enabled: boolean | null
          rls_forced: boolean | null
          schema_name: unknown
          table_name: unknown
        }
        Relationships: []
      }
      security_definer_audit: {
        Row: {
          anon_can_execute: boolean | null
          authenticated_can_execute: boolean | null
          configuration: string[] | null
          function_name: unknown
          identity_arguments: string | null
          public_can_execute: boolean | null
          schema_name: unknown
          security_definer: boolean | null
        }
        Relationships: []
      }
      trial_balance: {
        Row: {
          account_type: Database["bmt_db"]["Enums"]["coa_account_type"] | null
          branch_code: string | null
          branch_id: string | null
          coa_code: string | null
          coa_id: string | null
          coa_name: string | null
          fiscal_year: number | null
          net_debit_balance: number | null
          normal_balance:
            | Database["bmt_db"]["Enums"]["normal_balance_type"]
            | null
          period_no: number | null
          total_credit: number | null
          total_debit: number | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_journal_entries_branch"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_journal_lines_coa"
            columns: ["coa_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      workbench_summary: { Args: Record<PropertyKey, never>; Returns: Json }
      teller_post_savings_deposit: {
        Args: {
          p_amount: number
          p_channel?: string
          p_description?: string
          p_financial_account_id: string
          p_idempotency_key: string
          p_reference_number?: string
        }
        Returns: string
      }
      teller_get_cash_session: {
        Args: Record<PropertyKey, never>
        Returns: {
          business_date: string
          branch_id: string
          difference: number | null
          id: string
          opening_balance: number
          physical_closing_balance: number | null
          status: string
          system_balance: number
          system_closing_balance: number | null
        }[]
      }
      teller_open_cash_session: {
        Args: { p_branch_id?: string; p_opening_balance: number }
        Returns: string
      }
      teller_close_cash_session: {
        Args: { p_physical_closing_balance: number }
        Returns: {
          difference: number
          id: string
          physical_closing_balance: number
          system_closing_balance: number
        }[]
      }
      teller_disburse_loan: {
        Args: { p_idempotency_key: string; p_loan_application_id: string }
        Returns: string
      }
      teller_pay_loan_installment: {
        Args: { p_amount: number; p_idempotency_key: string; p_loan_schedule_id: string }
        Returns: string
      }
      refresh_loan_quality: {
        Args: Record<PropertyKey, never>
        Returns: number
      }
      refresh_savings_account_status: {
        Args: Record<PropertyKey, never>
        Returns: {
          dormant_at: string | null
          financial_account_id: string
          minimum_monthly_deposit: number
          monthly_deposit: number
          monthly_target_met: boolean
          product_code: string
          status: string
        }[]
      }
      teller_submit_savings_transfer: {
        Args: {
          p_amount: number
          p_description?: string
          p_financial_account_id: string
          p_idempotency_key: string
          p_reference_number: string
        }
        Returns: string
      }
      teller_search_savings_accounts: {
        Args: { p_search?: string }
        Returns: {
          account_number: string
          branch_id: string
          cif_number: string
          current_balance: number
          customer_id: string
          financial_account_id: string
          full_name: string
          status: string
        }[]
      }
      customer_simulate_murabahah: {
        Args: { p_loan_product_id: string; p_requested_amount: number; p_requested_tenor_months: number }
        Returns: {
          akad_code: string
          calculation_method: string
          disclaimer: string
          admin_fee: number
          loan_product_id: string
          loan_product_version_id: string
          margin_amount: number
          margin_rate: number
          monthly_installment: number
          principal: number
          schedule: Json
          selling_price: number
          total_initial_cost: number
        }[]
      }
      customer_submit_loan_application: {
        Args: {
          p_idempotency_key: string
          p_loan_product_id: string
          p_purpose: string
          p_requested_amount: number
          p_requested_tenor_months: number
          p_savings_account_id: string
        }
        Returns: string
      }
      customer_get_loan_product_requirements: {
        Args: { p_loan_product_id: string }
        Returns: {
          description: string | null
          is_required: boolean
          requirement_code: string
          requirement_name: string
          sort_order: number
        }[]
      }
      customer_upload_loan_document: {
        Args: {
          p_document_name: string
          p_file_size_bytes: number
          p_loan_application_id: string
          p_mime_type: string
          p_requirement_code: string
          p_storage_bucket: string
          p_storage_path: string
        }
        Returns: string
      }
      manager_create_murabahah_product: {
        Args: { p_admin_fee_type?: string; p_admin_fee_value?: number; p_code: string; p_margin_rate: number; p_maximum_principal: number; p_minimum_principal: number; p_name: string; p_loan_code: string; p_tenor_options: number[]; p_terms_and_conditions?: string }
        Returns: string
      }
      claim_financial_mutation: {
        Args: {
          p_idempotency_key: string
          p_operation: string
          p_request_hash?: string
        }
        Returns: {
          is_new: boolean
          request_id: string
          result_id: string
          status: string
        }[]
      }
      complete_financial_mutation: {
        Args: {
          p_request_id: string
          p_response_code?: number
          p_result_id?: string
          p_status: string
        }
        Returns: undefined
      }
      complete_manager_onboarding_review: {
        Args: {
          p_application_id: string
          p_approve: boolean
          p_reason?: string
        }
        Returns: undefined
      }
      complete_teller_onboarding_review: {
        Args: {
          p_application_id: string
          p_approve: boolean
          p_reason?: string
        }
        Returns: undefined
      }
      current_actor_id: { Args: never; Returns: string }
      current_user_can_access_account: {
        Args: { p_account_id: string }
        Returns: boolean
      }
      current_user_can_access_customer: {
        Args: { p_customer_id: string }
        Returns: boolean
      }
      current_user_can_access_onboarding: {
        Args: { p_application_id: string }
        Returns: boolean
      }
      current_user_can_edit_onboarding: {
        Args: { p_application_id: string }
        Returns: boolean
      }
      current_user_has_branch_access: {
        Args: { p_branch_id: string }
        Returns: boolean
      }
      current_user_has_permission: {
        Args: { p_branch_id?: string; p_permission_code: string }
        Returns: boolean
      }
      current_user_has_role: {
        Args: { p_branch_id?: string; p_role_code: string }
        Returns: boolean
      }
      current_user_is_active: { Args: never; Returns: boolean }
      current_user_is_superadmin: { Args: never; Returns: boolean }
      customer_request_installment_payment: {
        Args: {
          p_amount: number
          p_idempotency_key: string
          p_loan_schedule_id: string
        }
        Returns: string
      }
      data_volume_snapshot: {
        Args: never
        Returns: {
          recommended_action: string
          row_count: number
          table_name: string
        }[]
      }
      ensure_customer_savings_account: { Args: never; Returns: string }
      finalize_onboarding_application: {
        Args: { p_application_id: string }
        Returns: string
      }
      invalidate_onboarding_signatures: {
        Args: { p_application_id: string; p_reason?: string }
        Returns: undefined
      }
      manager_create_loan_product: {
        Args: {
          p_code: string
          p_loan_code: string
          p_maximum_principal: number
          p_maximum_tenor_months: number
          p_minimum_principal: number
          p_minimum_tenor_months: number
          p_name: string
          p_rate: number
        }
        Returns: string
      }
      manager_update_savings_product_rules: {
        Args: { p_dormant_after_days?: number | null; p_minimum_monthly_deposit: number; p_product_id: string }
        Returns: undefined
      }
      mark_transaction_posted:
        | {
            Args: { p_posted_by: string; p_transaction_id: string }
            Returns: undefined
          }
        | {
            Args: {
              p_idempotency_key: string
              p_posted_by: string
              p_transaction_id: string
            }
            Returns: undefined
          }
      next_sequence: {
        Args: {
          p_branch_id: string
          p_business_date?: string
          p_loan_code?: string
          p_padding?: number
          p_product_code?: string
          p_reset_policy?: Database["bmt_db"]["Enums"]["sequence_reset_policy"]
          p_sequence_type: Database["bmt_db"]["Enums"]["sequence_type"]
        }
        Returns: string
      }
      onboarding_application_signature_hash: {
        Args: { p_application_id: string }
        Returns: string
      }
      onboarding_default_branch: { Args: never; Returns: string }
      portal_get_deposit_accounts: {
        Args: never
        Returns: {
          account_number: string
          aro_type: string
          deposit_status: string
          financial_account_id: string
          maturity_date: string
          principal_amount: number
          product_code: string
          product_name: string
          profit_rate: number
          settlement_savings_account_id: string
          start_date: string
          status: string
          terminated_at: string
          termination_reason: string
        }[]
      }
      portal_get_financial_accounts: {
        Args: never
        Returns: {
          account_number: string
          account_type: string
          branch_code: string
          branch_name: string
          closed_at: string
          currency: string
          id: string
          opened_at: string
          product_category: string
          product_code: string
          product_name: string
          status: string
        }[]
      }
      portal_get_installment_payments: {
        Args: never
        Returns: {
          account_number: string
          id: string
          installment_no: number
          loan_account_id: string
          loan_schedule_id: string
          margin_amount: number
          other_amount: number
          paid_at: string
          penalty_amount: number
          principal_amount: number
          transaction_id: string
        }[]
      }
      portal_get_loan_accounts: {
        Args: never
        Returns: {
          account_number: string
          application_id: string
          disbursement_amount: number
          disbursement_date: string
          financial_account_id: string
          loan_status: string
          margin_amount: number
          maturity_date: string
          outstanding_margin: number
          outstanding_penalty: number
          outstanding_principal: number
          principal_amount: number
          product_code: string
          product_name: string
          rate: number
          savings_account_id: string
          status: string
          tenor_months: number
        }[]
      }
      portal_get_loan_applications: {
        Args: never
        Returns: {
          application_number: string
          created_at: string
          decided_at: string
          id: string
          loan_product_id: string
          product_code: string
          product_name: string
          purpose: string
          requested_amount: number
          requested_tenor_months: number
          savings_account_id: string
          status: string
          submitted_at: string
        }[]
      }
      portal_get_loan_schedules:
        | {
            Args: never
            Returns: {
              account_number: string
              days_overdue: number
              due_date: string
              id: string
              installment_no: number
              loan_account_id: string
              margin_due: number
              margin_paid: number
              opening_principal: number
              other_due: number
              other_paid: number
              paid_at: string
              penalty_paid: number
              principal_due: number
              principal_paid: number
              status: string
              total_due: number
            }[]
          }
        | {
            Args: { p_limit?: number; p_offset?: number }
            Returns: {
              account_number: string
              days_overdue: number
              due_date: string
              id: string
              installment_no: number
              loan_account_id: string
              margin_due: number
              margin_paid: number
              opening_principal: number
              other_due: number
              other_paid: number
              paid_at: string
              penalty_paid: number
              principal_due: number
              principal_paid: number
              status: string
              total_due: number
            }[]
          }
      portal_get_onboarding_applications: {
        Args: never
        Returns: {
          created_at: string
          form_version: number
          full_name: string
          id: string
          nik: string
          return_reason: string
          status: string
          submitted_at: string
          updated_at: string
        }[]
      }
      portal_get_onboarding_documents: {
        Args: { p_application_id: string }
        Returns: {
          application_id: string
          created_at: string
          document_type: string
          file_size_bytes: number
          id: string
          mime_type: string
          status: string
          storage_bucket: string
          storage_path: string
        }[]
      }
      portal_get_profile: {
        Args: never
        Returns: {
          birth_date: string
          birth_place: string
          branch_code: string
          branch_name: string
          cif_number: string
          email: string
          full_name: string
          gender: string
          id: string
          marital_status: string
          occupation: string
          phone: string
          registered_at: string
          status: string
        }[]
      }
      portal_get_savings_accounts: {
        Args: never
        Returns: {
          account_number: string
          available_balance: number
          blocked_balance: number
          current_balance: number
          dormant_at: string
          financial_account_id: string
          last_transaction_at: string
          product_code: string
          product_name: string
          status: string
        }[]
      }
      portal_get_savings_compliance: {
        Args: Record<PropertyKey, never>
        Returns: {
          account_number: string
          current_balance: number
          dormant_at: string | null
          financial_account_id: string
          minimum_monthly_deposit: number
          monthly_deposit: number
          monthly_target_met: boolean
          product_name: string
          status: string
        }[]
      }
      portal_get_transactions:
        | {
            Args: never
            Returns: {
              account_number: string
              amount: number
              channel: string
              currency: string
              description: string
              financial_account_id: string
              id: string
              posted_at: string
              reference_number: string
              status: string
              transaction_date: string
              transaction_number: string
              transaction_type: string
              value_date: string
            }[]
          }
        | {
            Args: { p_limit?: number; p_offset?: number }
            Returns: {
              account_number: string
              amount: number
              channel: string
              currency: string
              description: string
              financial_account_id: string
              id: string
              posted_at: string
              reference_number: string
              status: string
              transaction_date: string
              transaction_number: string
              transaction_type: string
              value_date: string
            }[]
          }
      post_journal:
        | {
            Args: { p_journal_id: string; p_posted_by: string }
            Returns: undefined
          }
        | {
            Args: {
              p_idempotency_key: string
              p_journal_id: string
              p_posted_by: string
            }
            Returns: undefined
          }
      require_active_user: { Args: { p_user_id: string }; Returns: undefined }
      require_open_fiscal_period: {
        Args: { p_business_date: string }
        Returns: string
      }
      require_open_teller_session: {
        Args: {
          p_branch_id: string
          p_business_date: string
          p_session_id: string
          p_teller_user_id: string
        }
        Returns: undefined
      }
      reverse_transaction:
        | {
            Args: {
              p_original_transaction_id: string
              p_reason: string
              p_reversed_by: string
            }
            Returns: string
          }
        | {
            Args: {
              p_idempotency_key: string
              p_original_transaction_id: string
              p_reason: string
              p_reversed_by: string
            }
            Returns: string
          }
      save_onboarding_draft: {
        Args: { p_data: Json; p_id?: string }
        Returns: string
      }
      sequence_period_key: {
        Args: {
          p_business_date: string
          p_reset_policy: Database["bmt_db"]["Enums"]["sequence_reset_policy"]
        }
        Returns: string
      }
      sign_onboarding_application: {
        Args: {
          p_application_id: string
          p_ip_address?: unknown
          p_signature_sha256: string
          p_signer_role: Database["bmt_db"]["Enums"]["onboarding_signature_role"]
          p_storage_bucket: string
          p_storage_path: string
          p_user_agent?: string
        }
        Returns: string
      }
      staff_review_loan_application: {
        Args: {
          p_application_id: string
          p_decision: string
          p_reason?: string
        }
        Returns: undefined
      }
      submit_onboarding_application: {
        Args: { p_application_id: string }
        Returns: undefined
      }
      validate_transaction_for_posting: {
        Args: { p_transaction_id: string }
        Returns: undefined
      }
    }
    Enums: {
      account_status:
        | "PENDING"
        | "ACTIVE"
        | "DORMANT"
        | "BLOCKED"
        | "PAST_DUE"
        | "RESTRUCTURED"
        | "MATURED"
        | "PAID_OFF"
        | "WRITTEN_OFF"
        | "CLOSED"
      address_type: "ID_CARD" | "DOMICILE" | "BUSINESS"
      approval_status: "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED"
      branch_type: "HQ" | "BRANCH" | "CASH_OFFICE"
      cash_movement_type:
        | "OPENING"
        | "CASH_IN"
        | "CASH_OUT"
        | "TRANSFER_IN"
        | "TRANSFER_OUT"
        | "ADJUSTMENT"
        | "CLOSING"
      cash_session_status: "OPEN" | "CLOSING" | "CLOSED"
      coa_account_type: "ASSET" | "LIABILITY" | "EQUITY" | "INCOME" | "EXPENSE"
      contract_type:
        | "CONVENTIONAL"
        | "MURABAHAH"
        | "MUDHARABAH"
        | "MUSYARAKAH"
        | "IJARAH"
        | "QARDH"
        | "OTHER"
      customer_status: "PROSPECT" | "ACTIVE" | "INACTIVE" | "BLOCKED" | "CLOSED"
      deposit_aro_type: "NONE" | "PRINCIPAL" | "PRINCIPAL_AND_PROFIT"
      deposit_status:
        | "PENDING"
        | "ACTIVE"
        | "MATURED"
        | "CLOSED"
        | "EARLY_TERMINATED"
      financial_account_type: "SAVINGS" | "DEPOSIT" | "LOAN"
      fiscal_period_status: "OPEN" | "SOFT_CLOSED" | "CLOSED"
      gender_type: "MALE" | "FEMALE"
      installment_status: "UPCOMING" | "DUE" | "PARTIAL" | "PAID" | "OVERDUE"
      journal_status: "DRAFT" | "POSTED" | "REVERSED"
      ledger_entry_type: "DEBIT" | "CREDIT"
      loan_account_status:
        | "READY_FOR_DISBURSEMENT"
        | "ACTIVE"
        | "PAST_DUE"
        | "RESTRUCTURED"
        | "PAID_OFF"
        | "WRITTEN_OFF"
        | "CLOSED"
      loan_application_status:
        | "DRAFT"
        | "SUBMITTED"
        | "SURVEY"
        | "ANALYSIS"
        | "REVIEW"
        | "APPROVED"
        | "REJECTED"
        | "CANCELLED"
      loan_ledger_component: "PRINCIPAL" | "MARGIN" | "PENALTY" | "FEE"
      normal_balance_type: "DEBIT" | "CREDIT"
      onboarding_document_status: "UPLOADED" | "VERIFIED" | "REJECTED"
      onboarding_product_status: "REQUESTED" | "APPROVED" | "REJECTED"
      onboarding_signature_role: "CUSTOMER" | "TELLER" | "MANAGER"
      onboarding_status:
        | "DRAFT"
        | "TELLER_REVIEW"
        | "MANAGER_REVIEW"
        | "RETURNED"
        | "REJECTED"
        | "APPROVED"
        | "COMPLETED"
        | "CANCELLED"
      product_category: "SAVINGS" | "DEPOSIT" | "LOAN"
      record_status: "ACTIVE" | "INACTIVE"
      sequence_reset_policy: "NEVER" | "YEARLY" | "MONTHLY" | "DAILY"
      sequence_type:
        | "CIF"
        | "SAVINGS_ACCOUNT"
        | "DEPOSIT_ACCOUNT"
        | "LOAN_ACCOUNT"
        | "LOAN_APPLICATION"
        | "TRANSACTION"
        | "JOURNAL"
        | "RECEIPT"
        | "REVERSAL"
      transaction_channel: "TELLER" | "BACKOFFICE" | "SYSTEM" | "ONLINE"
      transaction_status:
        | "DRAFT"
        | "PENDING_APPROVAL"
        | "APPROVED"
        | "POSTED"
        | "REVERSED"
        | "REJECTED"
        | "CANCELLED"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  bmt_db: {
    Enums: {
      account_status: [
        "PENDING",
        "ACTIVE",
        "DORMANT",
        "BLOCKED",
        "PAST_DUE",
        "RESTRUCTURED",
        "MATURED",
        "PAID_OFF",
        "WRITTEN_OFF",
        "CLOSED",
      ],
      address_type: ["ID_CARD", "DOMICILE", "BUSINESS"],
      approval_status: ["PENDING", "APPROVED", "REJECTED", "CANCELLED"],
      branch_type: ["HQ", "BRANCH", "CASH_OFFICE"],
      cash_movement_type: [
        "OPENING",
        "CASH_IN",
        "CASH_OUT",
        "TRANSFER_IN",
        "TRANSFER_OUT",
        "ADJUSTMENT",
        "CLOSING",
      ],
      cash_session_status: ["OPEN", "CLOSING", "CLOSED"],
      coa_account_type: ["ASSET", "LIABILITY", "EQUITY", "INCOME", "EXPENSE"],
      contract_type: [
        "CONVENTIONAL",
        "MURABAHAH",
        "MUDHARABAH",
        "MUSYARAKAH",
        "IJARAH",
        "QARDH",
        "OTHER",
      ],
      customer_status: ["PROSPECT", "ACTIVE", "INACTIVE", "BLOCKED", "CLOSED"],
      deposit_aro_type: ["NONE", "PRINCIPAL", "PRINCIPAL_AND_PROFIT"],
      deposit_status: [
        "PENDING",
        "ACTIVE",
        "MATURED",
        "CLOSED",
        "EARLY_TERMINATED",
      ],
      financial_account_type: ["SAVINGS", "DEPOSIT", "LOAN"],
      fiscal_period_status: ["OPEN", "SOFT_CLOSED", "CLOSED"],
      gender_type: ["MALE", "FEMALE"],
      installment_status: ["UPCOMING", "DUE", "PARTIAL", "PAID", "OVERDUE"],
      journal_status: ["DRAFT", "POSTED", "REVERSED"],
      ledger_entry_type: ["DEBIT", "CREDIT"],
      loan_account_status: [
        "READY_FOR_DISBURSEMENT",
        "ACTIVE",
        "PAST_DUE",
        "RESTRUCTURED",
        "PAID_OFF",
        "WRITTEN_OFF",
        "CLOSED",
      ],
      loan_application_status: [
        "DRAFT",
        "SUBMITTED",
        "SURVEY",
        "ANALYSIS",
        "REVIEW",
        "APPROVED",
        "REJECTED",
        "CANCELLED",
      ],
      loan_ledger_component: ["PRINCIPAL", "MARGIN", "PENALTY", "FEE"],
      normal_balance_type: ["DEBIT", "CREDIT"],
      onboarding_document_status: ["UPLOADED", "VERIFIED", "REJECTED"],
      onboarding_product_status: ["REQUESTED", "APPROVED", "REJECTED"],
      onboarding_signature_role: ["CUSTOMER", "TELLER", "MANAGER"],
      onboarding_status: [
        "DRAFT",
        "TELLER_REVIEW",
        "MANAGER_REVIEW",
        "RETURNED",
        "REJECTED",
        "APPROVED",
        "COMPLETED",
        "CANCELLED",
      ],
      product_category: ["SAVINGS", "DEPOSIT", "LOAN"],
      record_status: ["ACTIVE", "INACTIVE"],
      sequence_reset_policy: ["NEVER", "YEARLY", "MONTHLY", "DAILY"],
      sequence_type: [
        "CIF",
        "SAVINGS_ACCOUNT",
        "DEPOSIT_ACCOUNT",
        "LOAN_ACCOUNT",
        "LOAN_APPLICATION",
        "TRANSACTION",
        "JOURNAL",
        "RECEIPT",
        "REVERSAL",
      ],
      transaction_channel: ["TELLER", "BACKOFFICE", "SYSTEM", "ONLINE"],
      transaction_status: [
        "DRAFT",
        "PENDING_APPROVAL",
        "APPROVED",
        "POSTED",
        "REVERSED",
        "REJECTED",
        "CANCELLED",
      ],
    },
  },
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const
