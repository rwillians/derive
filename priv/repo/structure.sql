--
-- PostgreSQL database dump
--

\restrict KHyx6ripsSRTnHVVGpe93iROeW4If09sB18djHCbM4cTuxQlZU5Q1TH4RSuwigs

-- Dumped from database version 17.6 (Postgres.app)
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: derive_cursors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.derive_cursors (
    id character varying(96) NOT NULL,
    "position" integer NOT NULL,
    error character varying(255)
);


--
-- Name: derive_cursors_position_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.derive_cursors_position_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: derive_cursors_position_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.derive_cursors_position_seq OWNED BY public.derive_cursors."position";


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: derive_cursors position; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.derive_cursors ALTER COLUMN "position" SET DEFAULT nextval('public.derive_cursors_position_seq'::regclass);


--
-- Name: derive_cursors derive_cursors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.derive_cursors
    ADD CONSTRAINT derive_cursors_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- PostgreSQL database dump complete
--

\unrestrict KHyx6ripsSRTnHVVGpe93iROeW4If09sB18djHCbM4cTuxQlZU5Q1TH4RSuwigs

INSERT INTO public."schema_migrations" (version) VALUES (20260127044710);
