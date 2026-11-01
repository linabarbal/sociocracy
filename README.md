# Circle Commons

A free, open source workspace for organizations that use sociocracy. It is based on the practices in *Many Voices One Song: Shared Power with Sociocracy* by Ted J. Rau and Jerry Koch-Gonzalez.

## What it does

- **Circle map**: every circle around the general circle, with its leader and delegate links
- **Circles**: aim, domain, members, roles and terms, plus meetings, proposals, work and a logbook for each circle
- **Role selections**: a guided selection process that updates roles when the circle consents
- **Meetings**: minutes that follow the five-step meeting format, with key takeaways for everyone
- **Proposals**: proposal forming and the consent process, including objections
- **Work**: projects and tasks for each circle, with one person responsible for each task
- **People**: a directory of everyone, their circles and roles
- **Wiki**: courses and a library for agreements, policies and how-tos
- **Accounts**: email sign-in, invite-only access, Admin, Member and Viewer roles, and a private or public setting

## Two ways to run it

| Mode | How | Data |
| --- | --- | --- |
| Demo | Open `index.html`, or publish with an empty `config.js` | Saved in each visitor's own browser. No accounts. |
| Team | Connect a free Supabase database in `config.js` | Shared by everyone you invite, with sign-in and permissions |

## Set it up for your team

1. **Fork or copy** this repository and turn on **GitHub Pages** (Settings → Pages → Deploy from a branch → main).
2. **Create a free Supabase project** at supabase.com.
3. **Run `setup.sql`** in Supabase's SQL Editor. First change the email on its last line to your own; you become the first admin.
4. **Set the sign-in address**: in Supabase, Authentication → URL Configuration, set **Site URL** to your GitHub Pages address and add it under **Redirect URLs**.
5. **Set up email**: in Supabase, Authentication → Emails → SMTP Settings, connect an email account (for example Gmail with an app password). Supabase's built-in email only reaches members of your Supabase organization.
6. **Edit `config.js`** on GitHub and paste your Supabase Project URL and publishable key.
7. Open your site, sign in, and invite people from the **Access** page.

## Permissions

| Level | Can do |
| --- | --- |
| Admin | Everything, plus invite people, change access, and change the name and logo |
| Member | Read everything and create or edit content |
| Viewer | Read everything except contact details |

The rules are enforced by the database (row level security), not only by the page. A workspace always keeps at least one admin.

**Private or public:** a new workspace is private, so nothing is visible without signing in. An admin can switch it to **Public, read-only** in Data & settings: anyone with the link can then read everything except contact details, and only invited people can sign in to edit.

## Contributing

Suggestions and fixes are welcome. Open an issue to describe a problem or an idea.

## License

MIT. See `LICENSE`.
