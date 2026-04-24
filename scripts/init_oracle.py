import os
from pathlib import Path

import oracledb
from dotenv import load_dotenv


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    load_dotenv(repo_root / ".env")

    connection = oracledb.connect(
        user=os.environ["ORACLE_USER"],
        password=os.environ["ORACLE_PASSWORD"],
        dsn=os.environ["ORACLE_DSN"],
        config_dir=os.environ.get("ORACLE_WALLET_LOCATION") or None,
        wallet_location=os.environ.get("ORACLE_WALLET_LOCATION") or None,
        wallet_password=os.environ.get("ORACLE_WALLET_PASSWORD") or None,
    )

    sql_path = repo_root / "sql" / "oracle_schema.sql"
    sql_text = sql_path.read_text(encoding="utf-8")
    statements = [part.strip() for part in sql_text.split(";") if part.strip()]

    with connection:
        with connection.cursor() as cursor:
            for statement in statements:
                try:
                    cursor.execute(statement)
                except oracledb.DatabaseError as exc:
                    message = str(exc)
                    if "ORA-00955" in message:
                        continue
                    raise
        connection.commit()


if __name__ == "__main__":
    main()
