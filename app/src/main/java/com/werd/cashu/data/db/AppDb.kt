package com.werd.cashu.data.db

import android.content.Context
import androidx.room.*
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.werd.cashu.data.model.*
import kotlinx.coroutines.flow.Flow

@Dao
interface AccountDao {
    @Query("SELECT * FROM accounts WHERE del = 0 AND arch = 0 ORDER BY name")
    fun observeActive(): Flow<List<Account>>
    @Query("SELECT * FROM accounts") suspend fun all(): List<Account>
    /** upsert فقط — لا حذف فعلي أبدًا (الحذف = علامة del مع u أحدث) لحماية بيانات المستخدم والمزامنة. */
    @Upsert suspend fun upsert(a: Account)
    @Upsert suspend fun upsertAll(a: List<Account>)
}

@Dao
interface TxDao {
    @Query("SELECT * FROM tx WHERE del = 0 ORDER BY ts DESC")
    fun observeActive(): Flow<List<Tx>>
    @Query("SELECT * FROM tx") suspend fun all(): List<Tx>
    @Upsert suspend fun upsert(t: Tx)
    @Upsert suspend fun upsertAll(t: List<Tx>)
}

@Dao
interface BudgetDao {
    @Query("SELECT * FROM budgets WHERE del = 0") fun observeActive(): Flow<List<Budget>>
    @Query("SELECT * FROM budgets") suspend fun all(): List<Budget>
    @Upsert suspend fun upsertAll(b: List<Budget>)
}

@Dao
interface GoalDao {
    @Query("SELECT * FROM goals WHERE del = 0") fun observeActive(): Flow<List<Goal>>
    @Query("SELECT * FROM goals") suspend fun all(): List<Goal>
    @Upsert suspend fun upsertAll(g: List<Goal>)
}

@Dao
interface CatDao {
    @Query("SELECT * FROM categories ORDER BY ord") fun observeAll(): Flow<List<CatDef>>
    @Query("SELECT * FROM categories") suspend fun all(): List<CatDef>
    @Upsert suspend fun upsertAll(c: List<CatDef>)
}

@Dao
interface LoanDao {
    @Query("SELECT * FROM loans WHERE del = 0") fun observeActive(): Flow<List<Loan>>
    @Query("SELECT * FROM loans") suspend fun all(): List<Loan>
    @Upsert suspend fun upsertAll(l: List<Loan>)
}

@Dao
interface KvDao {
    @Query("SELECT * FROM kv WHERE `key` = :k") suspend fun get(k: String): RawKv?
    @Upsert suspend fun upsert(r: RawKv)
}

val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS `kv` (`key` TEXT NOT NULL, `value` TEXT NOT NULL, `ts` INTEGER NOT NULL, PRIMARY KEY(`key`))")
    }
}

@Database(
    entities = [Account::class, Tx::class, Budget::class, Goal::class, CatDef::class, Loan::class, RawKv::class],
    version = 2,
    exportSchema = true,
)
abstract class AppDb : RoomDatabase() {
    abstract fun accounts(): AccountDao
    abstract fun tx(): TxDao
    abstract fun budgets(): BudgetDao
    abstract fun goals(): GoalDao
    abstract fun cats(): CatDao
    abstract fun loans(): LoanDao
    abstract fun kv(): KvDao

    companion object {
        @Volatile private var inst: AppDb? = null
        fun get(ctx: Context): AppDb = inst ?: synchronized(this) {
            // بدون fallbackToDestructiveMigration عمدًا: ممنوع مسح بيانات المستخدم. أي تغيير مخطط يحتاج Migration صريح.
            inst ?: Room.databaseBuilder(ctx.applicationContext, AppDb::class.java, "cashu.db").addMigrations(MIGRATION_1_2).build().also { inst = it }
        }
    }
}
